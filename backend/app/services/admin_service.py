"""Admin operations: zones, users, analytics, pipeline, dashboard."""
from __future__ import annotations

import csv
import io
import json
import logging
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.cache import cache_delete_pattern
from app.models.audit_log import AuditLog
from app.models.merged_zone import MergedZone
from app.models.user import User
from app.models.zone_catalog_entry import ZoneCatalogEntryModel
from app.repositories.audit_repository import AuditRepository
from app.repositories.catalog_repository import CatalogRepository
from app.repositories.report_repository import ReportRepository
from app.repositories.user_repository import UserRepository
from app.repositories.zone_repository import ZoneRepository
from app.schemas.admin import (
    AdminAnalyticsOverview,
    AdminAuditEntry,
    AdminAuditListResponse,
    AdminCatalogCreate,
    AdminCatalogEntry,
    AdminCatalogUpdate,
    AdminDashboardStats,
    AdminPeopleSnapshot,
    AdminPipelineResult,
    AdminUserContributions,
    AdminUserListResponse,
    AdminUserSummary,
    AdminUserUpdate,
    AdminZoneSummary,
    AdminZoneUpdate,
    AdminZoneValidation,
)
from app.services.admin_events import (
    publish_catalog_updated,
    publish_dashboard_refresh,
    publish_zones_updated,
)
from app.services.aggregation_service import AggregationService
from app.services.audit_service import AuditService
from app.services.city_pulse_service import CityPulseService
from app.services.place_service import PlaceService
from app.services.zone_catalog import invalidate_catalog_cache
from app.services.zone_merge_service import ZoneMergeService

log = logging.getLogger(__name__)

_AUDIT_ADMIN_ACTIONS = (
    "report.admin_approve",
    "report.admin_reject",
    "report.admin_flag",
    "report.admin_keep_pending",
    "user.make_admin",
    "user.remove_admin",
    "user.pause",
    "user.resume",
    "config.update",
    "pipeline.rebuild",
)
_AUDIT_TRAVELER_ACTIONS = ("report.create",)
_AUDIT_RESULTS = {
    "report.create": "Waiting",
    "report.admin_approve": "Published",
    "report.admin_reject": "Wrong",
    "report.admin_flag": "Hold",
    "report.admin_keep_pending": "Waiting",
    "user.make_admin": "Made admin",
    "user.remove_admin": "Removed admin",
    "user.pause": "Paused",
    "user.resume": "Resumed",
    "config.update": "Saved tag rules",
    "pipeline.rebuild": "Map refreshed",
}


def _audit_action_types_for_scope(scope: str | None) -> list[str] | None:
    if scope == "admin":
        return list(_AUDIT_ADMIN_ACTIONS)
    if scope == "travelers":
        return list(_AUDIT_TRAVELER_ACTIONS)
    return None


def _zone_lifecycle(zone: MergedZone) -> str:
    if zone.confidence_score >= 70 and zone.report_count >= 10:
        return "defined"
    if zone.report_count >= 3 or zone.confidence_score >= 40:
        return "emerging"
    return "unthreshold"


def _zone_plain_summary(
    name: str,
    total: int,
    matching: int,
    top: str | None,
    lifecycle: str,
    pending: int = 0,
    flagged: int = 0,
    visible: int = 0,
) -> str:
    kind = _category_label(top) if top else "the same kind of place"
    if lifecycle == "defined":
        body = (
            f"{name} is established on the map. {total} tags were sent here"
            + (f", and {matching} of them agree it is mainly {kind}." if top else ".")
        )
    elif lifecycle == "emerging":
        extra = f" Most people tagged it as {kind}." if top else ""
        body = (
            f"{name} is still growing, with {total} tags so far.{extra} "
            "A few more matching tags would make this more certain."
        )
    else:
        noun = "tag" if total == 1 else "tags"
        body = (
            f"{name} is just getting started, with {total} {noun}. "
            "It will show more clearly once more people tag the same thing."
        )
    extras = []
    if visible:
        extras.append(f"{visible} already on the map")
    if pending:
        extras.append(f"{pending} waiting for review")
    if flagged:
        extras.append(f"{flagged} flagged")
    if not extras:
        return body
    return f"{body.rstrip('.')}. {'; '.join(extras)}."


def _category_label(value: str | None) -> str:
    labels = {
        "food": "Food",
        "activity": "Activity",
        "crowd": "Crowd",
        "safety": "Safety",
        "transport": "Transport",
        "school": "School",
        "issue": "Issue",
        "shopping": "Shopping",
        "nightlife": "Nightlife",
        "other": "Other",
    }
    if not value:
        return ""
    return labels.get(value.lower(), value.replace("_", " ").title())


def _mix_label(value: str | None) -> str:
    labels = {
        "local": "Mostly locals",
        "international": "Mostly visitors",
        "mixed": "Locals and visitors",
    }
    if not value:
        return "Not sure yet"
    return labels.get(value.lower(), value.replace("_", " ").title())


def _lifecycle_label(value: str) -> str:
    labels = {
        "defined": "Established",
        "emerging": "Growing",
        "unthreshold": "Just starting",
    }
    return labels.get(value, value.replace("_", " ").title())


def _audit_label(action: str) -> str:
    labels = {
        "report.admin_approve": "Approved a tag",
        "report.admin_reject": "Rejected a tag",
        "report.admin_flag": "Flagged a tag",
        "report.created": "Someone sent a tag",
        "report.approved": "A tag was approved",
        "report.rejected": "A tag was rejected",
        "report.flagged": "A tag was flagged",
    }
    return labels.get(action, action.replace(".", " ").replace("_", " "))


class AdminService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.zones = ZoneRepository(db)
        self.users = UserRepository(db)
        self.reports = ReportRepository(db)
        self.audit_repo = AuditRepository(db)
        self.catalog = CatalogRepository(db)
        self.audit = AuditService(db)

    # --- Dashboard -------------------------------------------------------

    def dashboard_stats(self) -> AdminDashboardStats:
        local = self.users.count_by_user_type("local_resident")
        intl = self.users.count_by_user_type("international_visitor")
        domestic = self.users.count_by_user_type("domestic_traveler")
        total_contrib = max(local + intl + domestic, 1)
        per_day = self.reports.count_reports_per_day(30)
        pending = self.reports.count_by_visibility("pending")
        flagged = self.reports.count_by_visibility("flagged")
        visible = self.reports.count_by_visibility("visible")
        active_zones = self.zones.list_active()
        defined = sum(1 for z in active_zones if _zone_lifecycle(z) == "defined")
        emerging = sum(1 for z in active_zones if _zone_lifecycle(z) == "emerging")
        from app.services.system_settings_service import SystemSettingsService

        threshold = max(
            SystemSettingsService(self.db).get_effective_settings().pending_min_reports_per_cell,
            1,
        )
        near = len(self.reports.list_near_threshold_cells(threshold))
        if pending:
            next_step = (
                f"{pending} tag{'s' if pending != 1 else ''} waiting for review. "
                "Open Review tags to approve, flag, or send back."
            )
        elif flagged:
            next_step = (
                f"{flagged} flagged tag{'s' if flagged != 1 else ''} need a closer look."
            )
        else:
            next_step = "Nothing is waiting. The public map is up to date."
        return AdminDashboardStats(
            pending_reports=pending,
            flagged_reports=flagged,
            active_zones=len(active_zones),
            total_users=self.users.count_all(),
            local_contributor_ratio=round(local / total_contrib, 3),
            reports_last_30_days=[{"date": d, "count": c} for d, c in per_day],
            visible_reports=visible,
            near_threshold_reports=near,
            defined_zones=defined,
            emerging_zones=emerging,
            local_users=local,
            international_users=intl,
            domestic_users=domestic,
            admin_users=self.users.count_admins(),
            plain_summary=next_step,
        )

    # --- Zones -------------------------------------------------------------

    def list_zones(self) -> list[AdminZoneSummary]:
        rows = self.zones.list_active() + [
            z for z in self._all_zones() if not z.is_active
        ]
        seen: set[UUID] = set()
        out: list[AdminZoneSummary] = []
        for zone in rows:
            if zone.zone_id in seen:
                continue
            seen.add(zone.zone_id)
            out.append(self._zone_summary(zone))
        return out

    def zone_validation(self, zone_id: UUID) -> AdminZoneValidation | None:
        zone = self.zones.get(zone_id)
        if zone is None:
            return None
        h3_indexes = list(zone.source_h3_indexes_json or [])
        reports = (
            self.reports.list_by_h3_indexes_for_admin(h3_indexes) if h3_indexes else []
        )
        categories: dict[str, int] = {}
        visible = pending = flagged = 0
        for r in reports:
            categories[r.category] = categories.get(r.category, 0) + 1
            if r.visibility_status == "visible":
                visible += 1
            elif r.visibility_status == "pending":
                pending += 1
            elif r.visibility_status == "flagged":
                flagged += 1
        top = max(categories, key=categories.get) if categories else None
        matching = categories.get(top, 0) if top else 0
        total = len(reports)
        lifecycle = _zone_lifecycle(zone)
        ratio = (matching / total) if total else 0.0
        return AdminZoneValidation(
            zone_id=zone.zone_id,
            display_name=zone.display_name,
            total_signals=total,
            matching_signals=matching,
            confidence=zone.confidence_score,
            top_category=top,
            last_updated=zone.updated_at,
            lifecycle_state=lifecycle,
            traveler_mix=zone.traveler_mix,
            function_type=zone.function_type,
            live_status=zone.live_status,
            matching_ratio=round(ratio, 3),
            plain_summary=_zone_plain_summary(
                zone.display_name,
                total,
                matching,
                top,
                lifecycle,
                pending=pending,
                flagged=flagged,
                visible=visible,
            ),
            visible_signals=visible,
            pending_signals=pending,
            flagged_signals=flagged,
        )

    def update_zone(self, zone_id: UUID, payload: AdminZoneUpdate) -> AdminZoneSummary | None:
        zone = self.zones.get(zone_id)
        if zone is None:
            return None
        if payload.display_name is not None:
            zone.display_name = payload.display_name
        if payload.summary is not None:
            zone.summary = payload.summary
        if payload.live_status is not None:
            zone.live_status = payload.live_status
        if payload.is_active is not None:
            zone.is_active = payload.is_active
        self.zones.upsert(zone)
        self.db.commit()
        self.db.refresh(zone)
        return self._zone_summary(zone)

    def zone_history(self, zone_id: UUID) -> list[dict]:
        snaps = self.zones.list_snapshots(zone_id)
        return [
            {
                "snapshot_date": s.snapshot_date.isoformat(),
                "confidence_score": s.confidence_score,
                "report_count": s.report_count,
                "crowd_level": s.crowd_level,
            }
            for s in snaps
        ]

    # --- Users -------------------------------------------------------------

    def list_users(
        self,
        *,
        page: int = 1,
        page_size: int = 50,
        search: str | None = None,
        user_type: str | None = None,
        role: str | None = None,
        status: str | None = None,
    ) -> AdminUserListResponse:
        is_admin = None
        if role == "admin":
            is_admin = True
        elif role == "contributor":
            is_admin = False
        is_active = None
        if status == "active":
            is_active = True
        elif status == "inactive":
            is_active = False
        rows, total = self.users.list_paginated(
            page=page,
            page_size=page_size,
            search=search,
            user_type=user_type,
            is_admin=is_admin,
            is_active=is_active,
        )
        items = [self._user_summary(user) for user in rows]
        return AdminUserListResponse(
            items=items,
            total=total,
            page=page,
            page_size=page_size,
            snapshot=AdminPeopleSnapshot(
                total=self.users.count_all(),
                active=self.users.count_active(),
                admins=self.users.count_admins(),
                contributors=max(self.users.count_all() - self.users.count_admins(), 0),
                local_residents=self.users.count_by_user_type("local_resident"),
                international_visitors=self.users.count_by_user_type(
                    "international_visitor"
                ),
                domestic_travelers=self.users.count_by_user_type("domestic_traveler"),
            ),
        )

    def update_user(
        self,
        user_id: UUID,
        payload: AdminUserUpdate,
        admin: User | None = None,
    ) -> AdminUserSummary | None:
        user = self.users.get_by_id(user_id)
        if user is None:
            return None
        actor_id = admin.id if admin is not None else None
        if payload.is_active is not None and payload.is_active != user.is_active:
            user.is_active = payload.is_active
            self.audit.record(
                actor_user_id=actor_id,
                action_type="user.resume" if user.is_active else "user.pause",
                entity_type="user",
                entity_id=user.id,
                payload={"is_active": user.is_active},
            )
        if payload.is_admin is not None and payload.is_admin != user.is_admin:
            user.is_admin = payload.is_admin
            self.audit.record(
                actor_user_id=actor_id,
                action_type="user.make_admin" if user.is_admin else "user.remove_admin",
                entity_type="user",
                entity_id=user.id,
                payload={"is_admin": user.is_admin},
            )
        self.users.save(user)
        self.db.commit()
        self.db.refresh(user)
        return self._user_summary(user)

    def user_contributions(self, user_id: UUID) -> AdminUserContributions | None:
        user = self.users.get_by_id(user_id)
        if user is None:
            return None
        counts = self.reports.count_grouped_by_visibility(user.id)
        badges: list[str] = []
        if counts.get("visible", 0) >= 10:
            badges.append("contributor")
        if counts.get("visible", 0) >= 50:
            badges.append("power_contributor")
        return AdminUserContributions(
            user_id=user.id,
            total_reports=sum(counts.values()),
            visible_reports=counts.get("visible", 0),
            pending_reports=counts.get("pending", 0),
            flagged_reports=counts.get("flagged", 0),
            badges=badges,
        )

    # --- Analytics ---------------------------------------------------------

    def analytics_overview(self) -> AdminAnalyticsOverview:
        active = self.zones.list_active()
        emerging = sum(1 for z in active if _zone_lifecycle(z) == "emerging")
        defined = sum(1 for z in active if _zone_lifecycle(z) == "defined")
        pulse = CityPulseService(self.db).compute()
        return AdminAnalyticsOverview(
            pending_reports=self.reports.count_by_visibility("pending"),
            flagged_reports=self.reports.count_by_visibility("flagged"),
            visible_reports=self.reports.count_by_visibility("visible"),
            active_zones=len(active),
            local_contributors=self.users.count_by_user_type("local_resident"),
            international_contributors=self.users.count_by_user_type("international_visitor"),
            domestic_contributors=self.users.count_by_user_type("domestic_traveler"),
            zones_emerging=emerging,
            zones_defined=defined,
            city_pulse=pulse.model_dump(mode="json"),
        )

    def export_reports(self, fmt: str = "json") -> str:
        rows, _ = self.reports.list_admin(page=1, page_size=5000)
        area_names = self._h3_area_names()
        grouped: dict[str, dict] = {}
        for r in rows:
            bucket = grouped.setdefault(
                r.h3_index,
                {
                    "h3_index": r.h3_index,
                    "area_name": area_names.get(r.h3_index) or "Unnamed area",
                    "categories": {},
                    "tag_counts": {},
                    "report_count": 0,
                },
            )
            bucket["report_count"] += 1
            bucket["categories"][r.category] = bucket["categories"].get(r.category, 0) + 1
            for tag in r.tags_json or []:
                bucket["tag_counts"][tag] = bucket["tag_counts"].get(tag, 0) + 1
        data = list(grouped.values())
        if fmt == "csv":
            buf = io.StringIO()
            writer = csv.DictWriter(
                buf,
                fieldnames=[
                    "Place or area",
                    "Number of tags",
                    "Most common kind of tag",
                    "How people described it",
                    "Map cell id",
                ],
            )
            writer.writeheader()
            for row in data:
                top_category = ""
                if row["categories"]:
                    top_category = max(row["categories"], key=row["categories"].get)
                tags = sorted(
                    row["tag_counts"].items(), key=lambda item: item[1], reverse=True
                )
                writer.writerow(
                    {
                        "Place or area": row["area_name"],
                        "Number of tags": row["report_count"],
                        "Most common kind of tag": _category_label(top_category),
                        "How people described it": "; ".join(name for name, _ in tags[:8]),
                        "Map cell id": row["h3_index"],
                    }
                )
            return buf.getvalue()
        return json.dumps(data, indent=2)

    def export_zones(self, fmt: str = "json") -> str:
        zones = [self._zone_summary(z) for z in self._all_zones()]
        if fmt == "csv":
            buf = io.StringIO()
            writer = csv.DictWriter(
                buf,
                fieldnames=[
                    "Place name",
                    "Who visits",
                    "How sure we are",
                    "Number of tags",
                    "Stage",
                    "Shown on the map",
                ],
            )
            writer.writeheader()
            for z in zones:
                writer.writerow(
                    {
                        "Place name": z.display_name,
                        "Who visits": _mix_label(z.traveler_mix),
                        "How sure we are": f"{z.confidence_score:.0f}%",
                        "Number of tags": z.report_count,
                        "Stage": _lifecycle_label(z.lifecycle_state),
                        "Shown on the map": "Yes" if z.is_active else "No",
                    }
                )
            return buf.getvalue()
        return json.dumps([z.model_dump(mode="json") for z in zones], indent=2)

    def export_audit(self, fmt: str = "json") -> str:
        rows = self.audit_repo.list_all(limit=5000)
        entries = [
            AdminAuditEntry(
                id=r.id,
                actor_user_id=r.actor_user_id,
                action_type=r.action_type,
                entity_type=r.entity_type,
                entity_id=r.entity_id,
                payload_json=r.payload_json,
                created_at=r.created_at,
            )
            for r in rows
        ]
        if fmt == "csv":
            buf = io.StringIO()
            writer = csv.DictWriter(
                buf,
                fieldnames=["When", "What happened", "What it applied to", "Record id"],
            )
            writer.writeheader()
            for e in entries:
                writer.writerow(
                    {
                        "When": e.created_at.isoformat(sep=" ", timespec="minutes"),
                        "What happened": _audit_label(e.action_type),
                        "What it applied to": e.entity_type.replace("_", " "),
                        "Record id": e.entity_id or "",
                    }
                )
            return buf.getvalue()
        return json.dumps([e.model_dump(mode="json") for e in entries], indent=2)

    # --- Audit log viewer --------------------------------------------------

    def list_audit(
        self,
        *,
        page: int = 1,
        page_size: int = 50,
        action_type: str | None = None,
        entity_type: str | None = None,
        scope: str | None = None,
        q: str | None = None,
        since: datetime | None = None,
        until: datetime | None = None,
    ) -> AdminAuditListResponse:
        action_types = _audit_action_types_for_scope(scope)
        rows, total = self.audit_repo.list_paginated(
            page=page,
            page_size=page_size,
            action_type=action_type,
            entity_type=entity_type,
            action_types=action_types,
            q=q,
            since=since,
            until=until,
        )
        area_names = self._h3_area_names()
        items = [self._audit_entry(r, area_names) for r in rows]
        return AdminAuditListResponse(items=items, total=total, page=page, page_size=page_size)

    # --- Catalog -----------------------------------------------------------

    def list_catalog(self) -> list[AdminCatalogEntry]:
        self.catalog.seed_from_static()
        self.db.commit()
        return [self._catalog_entry(r) for r in self.catalog.list_all()]

    def create_catalog(self, payload: AdminCatalogCreate) -> AdminCatalogEntry:
        row = ZoneCatalogEntryModel(
            zone_id=payload.zone_id,
            zone_name=payload.zone_name,
            city=payload.city,
            zone_type=payload.zone_type.upper(),
            radius_km=payload.radius_km,
            center_lat=payload.center_lat,
            center_lng=payload.center_lng,
            characteristics_json=list(payload.characteristics),
            default_local_ratio=payload.default_local_ratio,
            is_active=payload.is_active,
        )
        self.catalog.create(row)
        self.db.commit()
        invalidate_catalog_cache()
        publish_catalog_updated(source="catalog_create")
        return self._catalog_entry(row)

    def update_catalog(
        self, zone_id: str, payload: AdminCatalogUpdate
    ) -> AdminCatalogEntry | None:
        row = self.catalog.get(zone_id)
        if row is None:
            return None
        if payload.zone_name is not None:
            row.zone_name = payload.zone_name
        if payload.city is not None:
            row.city = payload.city
        if payload.zone_type is not None:
            row.zone_type = payload.zone_type.upper()
        if payload.radius_km is not None:
            row.radius_km = payload.radius_km
        if payload.center_lat is not None:
            row.center_lat = payload.center_lat
        if payload.center_lng is not None:
            row.center_lng = payload.center_lng
        if payload.characteristics is not None:
            row.characteristics_json = list(payload.characteristics)
        if payload.default_local_ratio is not None:
            row.default_local_ratio = payload.default_local_ratio
        if payload.is_active is not None:
            row.is_active = payload.is_active
        self.catalog.save(row)
        self.db.commit()
        invalidate_catalog_cache()
        publish_catalog_updated(source="catalog_update")
        return self._catalog_entry(row)

    def delete_catalog(self, zone_id: str) -> bool:
        row = self.catalog.get(zone_id)
        if row is None:
            return False
        self.catalog.delete(row)
        self.db.commit()
        invalidate_catalog_cache()
        publish_catalog_updated(source="catalog_delete")
        return True

    # --- Pipeline ----------------------------------------------------------

    def rebuild_cells(
        self, h3_indexes: list[str] | None = None, admin: User | None = None
    ) -> AdminPipelineResult:
        started = datetime.now(timezone.utc)
        if h3_indexes:
            AggregationService(self.db).recompute_cells(h3_indexes)
            count = len(h3_indexes)
        else:
            rows, total = self.reports.list_admin(page=1, page_size=5000)
            indexes = {r.h3_index for r in rows}
            AggregationService(self.db).recompute_cells(indexes)
            count = len(indexes)
        self.db.commit()
        return self._finish_pipeline(
            AdminPipelineResult(
                job="rebuild-cells",
                started_at=started,
                affected_counts={"h3_cells": count},
                message=f"Recomputed {count} H3 cell aggregates.",
            ),
            admin,
        )

    def _finish_pipeline(
        self, result: AdminPipelineResult, admin: User | None
    ) -> AdminPipelineResult:
        if admin is not None:
            self.audit.record(
                actor_user_id=admin.id,
                action_type="pipeline.rebuild",
                entity_type="pipeline",
                payload={"job": result.job},
            )
            self.db.commit()
        return result

    def rebuild_places(self, admin: User | None = None) -> AdminPipelineResult:
        started = datetime.now(timezone.utc)
        places = PlaceService(self.db).rebuild_all()
        self.db.commit()
        return self._finish_pipeline(
            AdminPipelineResult(
                job="rebuild-places",
                started_at=started,
                affected_counts={"places": len(places)},
                message=f"Rebuilt {len(places)} places.",
            ),
            admin,
        )

    def rebuild_zones(self, admin: User | None = None) -> AdminPipelineResult:
        started = datetime.now(timezone.utc)
        zones = ZoneMergeService(self.db).rebuild_all()
        self.db.commit()
        publish_zones_updated(source="rebuild-zones")
        return self._finish_pipeline(
            AdminPipelineResult(
                job="rebuild-zones",
                started_at=started,
                affected_counts={"zones": len(zones)},
                message=f"Rebuilt {len(zones)} merged zones.",
            ),
            admin,
        )

    def rebuild_all(self, admin: User | None = None) -> AdminPipelineResult:
        started = datetime.now(timezone.utc)
        rows, _ = self.reports.list_admin(page=1, page_size=5000)
        indexes = {r.h3_index for r in rows}
        AggregationService(self.db).recompute_cells(indexes)
        self.db.commit()
        places = PlaceService(self.db).rebuild_all()
        zones = ZoneMergeService(self.db).rebuild_all()
        self.db.commit()
        publish_zones_updated(source="rebuild-all")
        publish_dashboard_refresh(source="rebuild-all")
        return self._finish_pipeline(
            AdminPipelineResult(
                job="rebuild-all",
                started_at=started,
                affected_counts={
                    "h3_cells": len(indexes),
                    "places": len(places),
                    "zones": len(zones),
                },
                message="Full pipeline rebuild completed.",
            ),
            admin,
        )

    def invalidate_cache(self, admin: User | None = None) -> AdminPipelineResult:
        started = datetime.now(timezone.utc)
        cache_delete_pattern("zones:*")
        cache_delete_pattern("city:pulse:*")
        cache_delete_pattern("reports:pending:*")
        return self._finish_pipeline(
            AdminPipelineResult(
                job="invalidate-cache",
                started_at=started,
                affected_counts={},
                message="Cache invalidation requested.",
            ),
            admin,
        )

    # --- Helpers -----------------------------------------------------------

    def _audit_entry(self, row: AuditLog, area_names: dict[str, str]) -> AdminAuditEntry:
        payload = row.payload_json or {}
        h3_index = str(payload.get("h3_index") or "")
        tags = payload.get("tags") or []
        if not isinstance(tags, list):
            tags = []
        actor = self.users.get_by_id(row.actor_user_id) if row.actor_user_id else None
        name = (actor.display_name or "").strip() if actor else ""
        if row.action_type == "report.create":
            who = name or "Traveler"
        else:
            who = name or "Admin"
        area_name = area_names.get(h3_index)
        if not area_name and h3_index:
            try:
                from app.services import h3_service
                from app.services.landmark_service import landmark_for_centroid
                from app.services.sensitive_sites import public_place_name

                lat, lng = h3_service.cell_centroid(h3_index)
                landmark, _ = landmark_for_centroid(lat, lng)
                area_name = public_place_name(landmark, lat, lng)
            except Exception:
                area_name = None
        return AdminAuditEntry(
            id=row.id,
            actor_user_id=row.actor_user_id,
            action_type=row.action_type,
            entity_type=row.entity_type,
            entity_id=row.entity_id,
            payload_json=payload or None,
            created_at=row.created_at,
            actor_label=who,
            area_name=area_name,
            category=str(payload["category"]) if payload.get("category") else None,
            tags=[str(t) for t in tags],
            result=_AUDIT_RESULTS.get(row.action_type),
            reason=str(payload["reason"]) if payload.get("reason") else None,
        )

    def _all_zones(self) -> list[MergedZone]:
        from sqlalchemy import select

        stmt = select(MergedZone)
        return list(self.db.execute(stmt).scalars())

    def _user_summary(self, user) -> AdminUserSummary:
        counts = self.reports.count_grouped_by_visibility(user.id)
        return AdminUserSummary(
            id=user.id,
            email=user.email,
            display_name=user.display_name,
            user_type=user.user_type,
            traveler_type=user.traveler_type,
            country_of_origin=user.country_of_origin,
            city_of_origin=user.city_of_origin,
            is_active=user.is_active,
            is_admin=user.is_admin,
            report_count=sum(counts.values()),
            visible_reports=counts.get("visible", 0),
            pending_reports=counts.get("pending", 0),
            flagged_reports=counts.get("flagged", 0),
            created_at=user.created_at,
        )

    def _h3_area_names(self) -> dict[str, str]:
        from app.repositories.place_repository import PlaceRepository

        names: dict[str, str] = {}
        for zone in self._all_zones():
            for idx in zone.source_h3_indexes_json or []:
                names.setdefault(idx, zone.display_name)
        for place in PlaceRepository(self.db).list_active():
            for idx in place.source_h3_indexes_json or []:
                names.setdefault(idx, place.display_name)
        return names

    def _zone_summary(self, zone: MergedZone) -> AdminZoneSummary:
        return AdminZoneSummary(
            zone_id=zone.zone_id,
            display_name=zone.display_name,
            slug=zone.slug,
            traveler_mix=zone.traveler_mix,
            function_type=zone.function_type,
            live_status=zone.live_status,
            confidence_score=zone.confidence_score,
            report_count=zone.report_count,
            is_active=zone.is_active,
            lifecycle_state=_zone_lifecycle(zone),
        )

    @staticmethod
    def _catalog_entry(row: ZoneCatalogEntryModel) -> AdminCatalogEntry:
        return AdminCatalogEntry(
            zone_id=row.zone_id,
            zone_name=row.zone_name,
            city=row.city,
            zone_type=row.zone_type,
            radius_km=row.radius_km,
            center_lat=row.center_lat,
            center_lng=row.center_lng,
            characteristics=list(row.characteristics_json or []),
            default_local_ratio=row.default_local_ratio,
            is_active=row.is_active,
        )
