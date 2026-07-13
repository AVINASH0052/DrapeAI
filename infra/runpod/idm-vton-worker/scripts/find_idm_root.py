#!/usr/bin/env python3
"""Discover IDM-VTON install path inside base images and write env hint."""

from __future__ import annotations

import os
from pathlib import Path

CANDIDATES = [
    "/IDM-VTON",
    "/app/IDM-VTON",
    "/workspace/IDM-VTON",
    "/root/IDM-VTON",
    "/home/user/IDM-VTON",
    "/opt/IDM-VTON",
]


def looks_like_idm(path: Path) -> bool:
    return (path / "src" / "tryon_pipeline.py").is_file() or (
        path / "gradio_demo" / "app.py"
    ).is_file()


def main() -> None:
    found = None
    for c in CANDIDATES:
        p = Path(c)
        if p.is_dir() and looks_like_idm(p):
            found = str(p)
            break
    if found is None:
        for root in ("/", "/app", "/workspace", "/root", "/home"):
            root_p = Path(root)
            if not root_p.is_dir():
                continue
            for p in root_p.rglob("tryon_pipeline.py"):
                found = str(p.parent.parent)
                break
            if found:
                break

    print("IDM root candidates scanned")
    if found:
        print(f"FOUND {found}")
        Path("/app/idm_root.txt").write_text(found + "\n", encoding="utf-8")
        # Soft link for infer.py default
        target = Path("/IDM-VTON")
        if not target.exists():
            try:
                target.symlink_to(found)
            except OSError as e:
                print(f"symlink skip: {e}")
    else:
        print("WARN: IDM-VTON tree not found in base image")
        # Still list top-level for debugging
        for root in ("/", "/app", "/workspace"):
            try:
                print(root, os.listdir(root)[:30])
            except OSError:
                pass


if __name__ == "__main__":
    main()
