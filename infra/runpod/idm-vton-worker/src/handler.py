"""RunPod Serverless handler for IDM-VTON.

Deploy as a Queue endpoint. DrapeAI will call:
  POST https://api.runpod.ai/v2/{ENDPOINT_ID}/runsync
"""

from __future__ import annotations

import base64
import logging
import traceback

import runpod

from infer import run_tryon

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("idm-vton-worker")


def _cuda_diag() -> dict:
    """Report GPU / torch info without loading IDM-VTON."""
    import torch

    info: dict = {
        "torch": torch.__version__,
        "torch_cuda": torch.version.cuda,
        "cuda_available": bool(torch.cuda.is_available()),
        "arch_list": list(torch.cuda.get_arch_list())
        if hasattr(torch.cuda, "get_arch_list")
        else [],
    }
    if not torch.cuda.is_available():
        return info
    info["device_count"] = torch.cuda.device_count()
    info["device_name"] = torch.cuda.get_device_name(0)
    info["capability"] = list(torch.cuda.get_device_capability(0))
    try:
        a = torch.randn(64, 64, device="cuda", dtype=torch.float16)
        b = torch.randn(64, 64, device="cuda", dtype=torch.float16)
        c = a @ b
        torch.cuda.synchronize()
        info["matmul_fp16_ok"] = True
        info["matmul_sample"] = float(c[0, 0].detach().cpu())
    except Exception as e:
        info["matmul_fp16_ok"] = False
        info["matmul_error"] = str(e)
    return info


def handler(job: dict) -> dict:
    try:
        inp = job.get("input") or {}
        if inp.get("diag"):
            return {"diag": _cuda_diag()}

        person = inp.get("person_image") or inp.get("person_image_b64")
        garment = inp.get("garment_image") or inp.get("garment_image_b64")
        if not person or not garment:
            return {
                "error": "person_image and garment_image (base64) are required",
            }

        category = (inp.get("category") or "upper_body").strip()
        desc = (inp.get("garment_description") or "").strip()

        result = run_tryon(
            person,
            garment,
            category=category,
            garment_description=desc,
        )
        return {
            "image": base64.b64encode(result.image_png).decode("ascii"),
            "model": "idm-vton",
            "width": result.width,
            "height": result.height,
            "stub": bool(result.stub),
        }
    except Exception as e:
        logger.error("try-on failed: %s\n%s", e, traceback.format_exc())
        payload = {"error": str(e)}
        try:
            payload["diag"] = _cuda_diag()
        except Exception:
            pass
        return payload


runpod.serverless.start({"handler": handler})
