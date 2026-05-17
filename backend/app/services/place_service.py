"""Builds and updates Place rows from H3 cell aggregates and the place catalog."""
from __future__ import annotations

from collections import defaultdict
from collections.abc import Iterable
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy.orm import Session

from app.core.cache import cache_delete_pattern
from app.models.h3_cell_aggregate import H3CellAggregate
from app.models.place import Place
from app.repositories.h3_repository import H3Repository
from app.repositories.place_repository import PlaceRepository
from app.repositories.report_repository import ReportRepository
from app.services import h3_service
from app.services.place_catalog import CEBU_PLACE_CATALOG, CatalogPlace, catalog_by_slug
from app.services.polygon_service import PolygonService
from app.utils.place_geometry import point_in_geojson
from app.utils.place_type_utils import dominant_place_type, place_type_from_function


class PlaceService:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.h3_repo = H3Repository(db)
        self.place_repo = PlaceRepository(db)
        self.report_repo = ReportRepository(db)

    def sync_catalog_places(self) -> list[Place]:
        """Ensure every catalog entry exists as a Place row."""
        synced: list[Place] = []
        for entry in CEBU_PLACE_CATALOG:
            existing = self.place_repo.get_by_slug(entry.slug)
            centroid_lat, centroid_lng = 0.0, 0.0
            if entry.polygon_geojson.get("type") == "Polygon":
                ring = entry.polygon_geojson["coordinates"][0]
                if ring:
                    lats = [pt[1] for pt in ring]
                    lngs = [pt[0] for pt in ring]
                    centroid_lat = sum(lats) / len(lats)
                    centroid_lng = sum(lngs) / len(lngs)

            place = existing or Place(
                place_id=uuid4(),
                slug=entry.slug,
                display_name=entry.display_name,
                place_type=entry.default_place_type,
                source="catalog",
                polygon_geojson=entry.polygon_geojson,
                centroid_lat=centroid_lat,
                centroid_lng=centroid_lng,
                is_active=True,
            )
            place.display_name = entry.display_name
            place.place_type = entry.default_place_type
            place.polygon_geojson = entry.polygon_geojson
            place.polygon_geometry = PolygonService.geojson_to_postgis_geometry(
                entry.polygon_geojson,
                dialect_name=self.db.get_bind().dialect.name,
            )
            place.centroid_lat = centroid_lat
            place.centroid_lng = centroid_lng
            place.source = "catalog"
            synced.append(self.place_repo.upsert(place))
        self.db.commit()
        return synced

    def assign_cells(self, cells: Iterable[H3CellAggregate]) -> set[UUID]:
        """Link cells to catalog places by centroid and tag hints."""
        self.sync_catalog_places()
        slug_to_place = {
            p.slug: p for p in self.place_repo.list_all_catalog()
        }
        touched_places: set[UUID] = set()

        for cell in cells:
            if cell.report_count <= 0:
                cell.place_id = None
                continue
            lat, lng = h3_service.cell_centroid(cell.h3_index)
            forced_slug = self._place_slug_from_cell_tags(cell)
            place: Place | None = None
            if forced_slug:
                place = slug_to_place.get(forced_slug)
            if place is None:
                place = self._place_from_centroid(lat, lng, slug_to_place)
            cell.place_id = place.place_id if place else None
            if place:
                touched_places.add(place.place_id)

        self.db.flush()
        return touched_places

    def rebuild_place(self, place_id: UUID) -> Place | None:
        place = self.place_repo.get(place_id)
        if place is None:
            return None
        cells = [
            c
            for c in self.h3_repo.list_all_active()
            if c.place_id == place_id and c.report_count > 0
        ]
        if not cells:
            place.report_count = 0
            place.confidence_score = 0.0
            place.source_h3_indexes_json = []
            place.is_active = False
            self.place_repo.upsert(place)
            return place

        h3_indexes = [c.h3_index for c in cells]
        function_counter: dict[str, int] = defaultdict(int)
        for c in cells:
            function_counter[c.function_type] += 1

        catalog = catalog_by_slug(place.slug)
        if function_counter:
            derived = dominant_place_type(dict(function_counter))
            if derived in {"emerging", "general"} and catalog:
                place.place_type = catalog.default_place_type
            else:
                place.place_type = derived
        elif catalog:
            place.place_type = catalog.default_place_type

        place.source_h3_indexes_json = h3_indexes
        place.polygon_geojson = PolygonService.cells_to_geojson_polygon(h3_indexes)
        place.polygon_geometry = PolygonService.geojson_to_postgis_geometry(
            place.polygon_geojson,
            dialect_name=self.db.get_bind().dialect.name,
        )
        lat, lng = PolygonService.centroid_of_cells(h3_indexes)
        place.centroid_lat = float(lat)
        place.centroid_lng = float(lng)
        place.report_count = sum(c.report_count for c in cells)
        place.confidence_score = round(
            sum(c.confidence_score for c in cells) / len(cells), 2
        )
        place.is_active = place.report_count > 0
        place.updated_at = datetime.utcnow()
        return self.place_repo.upsert(place)

    def rebuild_places_for_cells(self, h3_indexes: Iterable[str]) -> list[Place]:
        cells = self.h3_repo.list_by_indexes(h3_indexes)
        if not cells:
            return []
        touched = self.assign_cells(cells)
        # Also reassign any active cell (catalog membership can shift).
        all_active = self.h3_repo.list_all_active()
        touched |= self.assign_cells(all_active)

        rebuilt: list[Place] = []
        for place_id in touched:
            place = self.rebuild_place(place_id)
            if place is not None:
                rebuilt.append(place)
        self.db.commit()
        cache_delete_pattern("places:vp:*")
        return rebuilt

    def rebuild_all(self) -> list[Place]:
        self.sync_catalog_places()
        active = self.h3_repo.list_all_active()
        touched = self.assign_cells(active)
        rebuilt: list[Place] = []
        for place_id in touched:
            place = self.rebuild_place(place_id)
            if place is not None:
                rebuilt.append(place)
        self.db.commit()
        cache_delete_pattern("places:vp:*")
        return rebuilt

    def _place_from_centroid(
        self, lat: float, lng: float, slug_to_place: dict[str, Place]
    ) -> Place | None:
        for entry in CEBU_PLACE_CATALOG:
            if point_in_geojson(entry.polygon_geojson, lat=lat, lng=lng):
                return slug_to_place.get(entry.slug)
        return None

    def _place_slug_from_cell_tags(self, cell: H3CellAggregate) -> str | None:
        tag_counts = cell.tag_counts_json or {}
        normalized = {str(k).lower().strip(): int(v) for k, v in tag_counts.items()}
        for entry in CEBU_PLACE_CATALOG:
            for alias in entry.tag_aliases:
                if alias in normalized and normalized[alias] > 0:
                    return entry.slug
            for tag in normalized:
                if any(alias in tag for alias in entry.tag_aliases):
                    return entry.slug
        if cell.dominant_category == "school":
            for entry in CEBU_PLACE_CATALOG:
                if entry.default_place_type == "school":
                    lat, lng = h3_service.cell_centroid(cell.h3_index)
                    if point_in_geojson(entry.polygon_geojson, lat=lat, lng=lng):
                        return entry.slug
        return None
