from __future__ import annotations

import json
import logging
import smtplib
import ssl
import urllib.error
import urllib.request
from email.message import EmailMessage

from app.core.config import settings

log = logging.getLogger(__name__)

_GENERIC_SUBJECT = "Your StrollWise password reset code"


def smtp_configured() -> bool:
    return bool((settings.smtp_host or "").strip() and (settings.smtp_from or "").strip())


def resend_configured() -> bool:
    return bool((settings.resend_api_key or "").strip())


def mail_configured() -> bool:
    return smtp_configured() or resend_configured()


def send_password_reset_code(to_email: str, code: str) -> bool:
    """Send the 6-digit reset code. Returns True if a provider accepted it."""
    body = (
        f"Use this code to reset your StrollWise password:\n\n"
        f"    {code}\n\n"
        f"It expires in {settings.password_reset_minutes} minutes. "
        f"If you did not ask for this, you can ignore this email."
    )
    if smtp_configured():
        try:
            _send_smtp(to_email, _GENERIC_SUBJECT, body)
            return True
        except Exception:
            log.exception("SMTP password-reset send failed")
    if resend_configured():
        try:
            _send_resend(to_email, _GENERIC_SUBJECT, body)
            return True
        except Exception:
            log.exception("Resend password-reset send failed")
    return False


def _send_smtp(to_email: str, subject: str, body: str) -> None:
    msg = EmailMessage()
    sender = (settings.smtp_from or "").strip()
    msg["From"] = sender
    msg["To"] = to_email
    msg["Subject"] = subject
    msg.set_content(body)
    host = (settings.smtp_host or "").strip()
    port = int(settings.smtp_port or 587)
    user = (settings.smtp_user or "").strip()
    password = settings.smtp_password or ""
    context = ssl.create_default_context()
    if port == 465:
        with smtplib.SMTP_SSL(host, port, context=context, timeout=20) as smtp:
            if user:
                smtp.login(user, password)
            smtp.send_message(msg)
        return
    with smtplib.SMTP(host, port, timeout=20) as smtp:
        smtp.ehlo()
        smtp.starttls(context=context)
        smtp.ehlo()
        if user:
            smtp.login(user, password)
        smtp.send_message(msg)


def _send_resend(to_email: str, subject: str, body: str) -> None:
    sender = (settings.smtp_from or "").strip() or "StrollWise <noreply@strollwise.app>"
    payload = json.dumps(
        {
            "from": sender,
            "to": [to_email],
            "subject": subject,
            "text": body,
        }
    ).encode("utf-8")
    req = urllib.request.Request(
        "https://api.resend.com/emails",
        data=payload,
        method="POST",
        headers={
            "Authorization": f"Bearer {settings.resend_api_key.strip()}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            if resp.status >= 300:
                raise RuntimeError(f"Resend HTTP {resp.status}")
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"Resend HTTP {exc.code}") from exc
