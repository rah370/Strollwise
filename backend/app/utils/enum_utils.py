from __future__ import annotations


def slugify(text: str) -> str:
    return (
        "".join(ch.lower() if ch.isalnum() else "-" for ch in text)
        .strip("-")
        .replace("--", "-")
        .replace("---", "-")
    )
