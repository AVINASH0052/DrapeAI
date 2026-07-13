#!/usr/bin/env python3
"""Bake IDM-VTON preprocessing ckpts into the path hardcoded by fonixteam image."""

from __future__ import annotations

import os
import shutil
import sys

from huggingface_hub import hf_hub_download

DEST = "/runpod-volume/IDM-VTON/ckpt"
FILES = {
    "ckpt/humanparsing/parsing_atr.onnx": f"{DEST}/humanparsing/parsing_atr.onnx",
    "ckpt/humanparsing/parsing_lip.onnx": f"{DEST}/humanparsing/parsing_lip.onnx",
    "ckpt/densepose/model_final_162be9.pkl": f"{DEST}/densepose/model_final_162be9.pkl",
    "ckpt/openpose/ckpts/body_pose_model.pth": f"{DEST}/openpose/ckpts/body_pose_model.pth",
}


def download(remote: str) -> str:
    last = None
    for kwargs in (
        {"repo_id": "yisol/IDM-VTON", "repo_type": "space", "filename": remote},
        {"repo_id": "spaces/yisol/IDM-VTON", "filename": remote},
    ):
        try:
            return hf_hub_download(**kwargs)
        except Exception as e:  # noqa: BLE001
            last = e
            print(f"try fail {kwargs}: {e}", flush=True)
    raise RuntimeError(f"missing {remote}: {last}")


def main() -> int:
    for remote, local in FILES.items():
        os.makedirs(os.path.dirname(local), exist_ok=True)
        src = download(remote)
        shutil.copy2(src, local)
        print(f"OK {local} ({os.path.getsize(local)} bytes)", flush=True)
    for required in FILES.values():
        if not os.path.isfile(required):
            print(f"MISSING {required}", flush=True)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
