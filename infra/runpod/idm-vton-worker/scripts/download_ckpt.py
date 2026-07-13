#!/usr/bin/env python3
"""Download IDM-VTON preprocessing checkpoints into ckpt/.

Diffusion / UNet weights load from Hugging Face at runtime (yisol/IDM-VTON).
These files are required for openpose / parsing / densepose.
"""

from __future__ import annotations

import os
import sys

from huggingface_hub import hf_hub_download, snapshot_download

DEST = os.environ.get("BAKED_MODEL_DIR", "/app/IDM-VTON/ckpt")
# Space mirrors the required preprocessing weights.
SPACE_REPO = os.environ.get("IDM_CKPT_REPO", "spaces/yisol/IDM-VTON")


def main() -> int:
    os.makedirs(DEST, exist_ok=True)
    print(f"Downloading preprocessing ckpts → {DEST}", flush=True)
    try:
        snapshot_download(
            repo_id="yisol/IDM-VTON",
            allow_patterns=None,
            local_dir=os.environ.get("HF_CACHE", "/app/hf-cache"),
            local_dir_use_symlinks=False,
        )
    except Exception as e:
        print(f"Note: full model snapshot optional at build ({e})", flush=True)

    # Prefer Space tree for densepose/parsing/openpose layout.
    files = [
        "ckpt/densepose/model_final_162be9.pkl",
        "ckpt/humanparsing/parsing_atr.onnx",
        "ckpt/humanparsing/parsing_lip.onnx",
        "ckpt/openpose/ckpts/body_pose_model.pth",
    ]
    for rel in files:
        try:
            path = hf_hub_download(
                repo_id="yisol/IDM-VTON",
                filename=rel,
                repo_type="space",
                local_dir=os.path.dirname(DEST),
                local_dir_use_symlinks=False,
            )
            print(f"OK {rel} → {path}", flush=True)
        except Exception as e:
            # Fallback: some mirrors nest under ckpt only in the Space.
            try:
                path = hf_hub_download(
                    repo_id="spaces/yisol/IDM-VTON",
                    filename=rel,
                    local_dir=os.path.dirname(DEST),
                    local_dir_use_symlinks=False,
                )
                print(f"OK (alt) {rel} → {path}", flush=True)
            except Exception as e2:
                print(f"WARN missing {rel}: {e} / {e2}", flush=True)

    # Ensure expected layout under DEST
    for sub in ("densepose", "humanparsing", "openpose/ckpts"):
        os.makedirs(os.path.join(DEST, sub), exist_ok=True)

    print("ckpt download finished", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
