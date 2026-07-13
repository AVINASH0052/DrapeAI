"""IDM-VTON inference for RunPod Serverless.

Loads yisol/IDM-VTON from Hugging Face + local preprocessing ckpts.
Public API is stable for handler.py / DrapeAI.
"""

from __future__ import annotations

import base64
import io
import logging
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from PIL import Image

logger = logging.getLogger(__name__)

IDM_ROOT = os.environ.get("IDM_ROOT", "/app/IDM-VTON")
MODEL_DIR = os.environ.get("MODEL_DIR", "/opt/idm-ckpt")
BAKED_MODEL_DIR = os.environ.get("BAKED_MODEL_DIR", "/opt/idm-ckpt")
HF_MODEL = os.environ.get("IDM_HF_MODEL", "yisol/IDM-VTON")
ALLOW_STUB = os.environ.get("ALLOW_STUB", "0") == "1"
DENOISE_STEPS = int(os.environ.get("DENOISE_STEPS", "30"))
SEED = int(os.environ.get("SEED", "42"))

_pipeline: dict[str, Any] | None = None


@dataclass
class TryOnResult:
    image_png: bytes
    width: int
    height: int
    stub: bool = False


def _b64_to_pil(data: str) -> Image.Image:
    raw = base64.b64decode(data)
    return Image.open(io.BytesIO(raw)).convert("RGB")


def _pil_to_png_bytes(img: Image.Image) -> bytes:
    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=True)
    return buf.getvalue()


def _resolve_ckpt_dir() -> str:
    for path in (MODEL_DIR, BAKED_MODEL_DIR, f"{IDM_ROOT}/ckpt", "/app/ckpt"):
        if not path:
            continue
        densepose = os.path.join(path, "densepose", "model_final_162be9.pkl")
        if os.path.isfile(densepose):
            return path
        if os.path.isdir(path) and any(os.scandir(path)):
            return path
    return MODEL_DIR


def _ensure_idm_on_path() -> None:
    global IDM_ROOT
    hint = Path("/app/idm_root.txt")
    if hint.is_file():
        IDM_ROOT = hint.read_text(encoding="utf-8").strip() or IDM_ROOT
    if not Path(IDM_ROOT).is_dir():
        for c in (
            "/IDM-VTON",
            "/app/IDM-VTON",
            "/workspace/IDM-VTON",
            "/root/IDM-VTON",
        ):
            if Path(c).is_dir():
                IDM_ROOT = c
                break
    if IDM_ROOT not in sys.path:
        sys.path.insert(0, IDM_ROOT)
    gradio_demo = os.path.join(IDM_ROOT, "gradio_demo")
    if os.path.isdir(gradio_demo) and gradio_demo not in sys.path:
        sys.path.insert(0, gradio_demo)


def _stub_composite(person: Image.Image, garment: Image.Image) -> TryOnResult:
    w = max(person.width, garment.width)
    h = person.height + garment.height
    canvas = Image.new("RGB", (w, h), (245, 245, 245))
    canvas.paste(
        person.resize((min(w, person.width), min(h // 2, person.height))),
        (0, 0),
    )
    canvas.paste(
        garment.resize((min(w, garment.width), min(h // 2, garment.height))),
        (0, h // 2),
    )
    png = _pil_to_png_bytes(canvas)
    return TryOnResult(
        image_png=png, width=canvas.width, height=canvas.height, stub=True
    )


def load_pipeline() -> dict[str, Any]:
    """Lazy-load IDM-VTON once per worker process."""
    global _pipeline
    if _pipeline is not None:
        return _pipeline

    ckpt_dir = _resolve_ckpt_dir()
    logger.info("Loading IDM-VTON HF=%s ckpt=%s", HF_MODEL, ckpt_dir)

    try:
        _ensure_idm_on_path()
        # Workdir must be IDM root so relative ckpt / config paths resolve.
        os.chdir(IDM_ROOT)

        import torch
        from torchvision import transforms
        from transformers import (
            AutoTokenizer,
            CLIPImageProcessor,
            CLIPTextModel,
            CLIPTextModelWithProjection,
            CLIPVisionModelWithProjection,
        )
        from diffusers import AutoencoderKL, DDPMScheduler

        from src.tryon_pipeline import StableDiffusionXLInpaintPipeline as TryonPipeline
        from src.unet_hacked_garmnet import UNet2DConditionModel as UNet2DConditionModel_ref
        from src.unet_hacked_tryon import UNet2DConditionModel
        from preprocess.humanparsing.run_parsing import Parsing
        from preprocess.openpose.run_openpose import OpenPose

        device = "cuda:0" if torch.cuda.is_available() else "cpu"
        dtype = torch.float16 if device.startswith("cuda") else torch.float32

        unet = UNet2DConditionModel.from_pretrained(
            HF_MODEL, subfolder="unet", torch_dtype=dtype
        )
        unet.requires_grad_(False)

        tokenizer_one = AutoTokenizer.from_pretrained(
            HF_MODEL, subfolder="tokenizer", revision=None, use_fast=False
        )
        tokenizer_two = AutoTokenizer.from_pretrained(
            HF_MODEL, subfolder="tokenizer_2", revision=None, use_fast=False
        )
        noise_scheduler = DDPMScheduler.from_pretrained(HF_MODEL, subfolder="scheduler")
        text_encoder_one = CLIPTextModel.from_pretrained(
            HF_MODEL, subfolder="text_encoder", torch_dtype=dtype
        )
        text_encoder_two = CLIPTextModelWithProjection.from_pretrained(
            HF_MODEL, subfolder="text_encoder_2", torch_dtype=dtype
        )
        image_encoder = CLIPVisionModelWithProjection.from_pretrained(
            HF_MODEL, subfolder="image_encoder", torch_dtype=dtype
        )
        vae = AutoencoderKL.from_pretrained(HF_MODEL, subfolder="vae", torch_dtype=dtype)
        unet_encoder = UNet2DConditionModel_ref.from_pretrained(
            HF_MODEL, subfolder="unet_encoder", torch_dtype=dtype
        )
        unet_encoder.requires_grad_(False)
        image_encoder.requires_grad_(False)
        vae.requires_grad_(False)
        text_encoder_one.requires_grad_(False)
        text_encoder_two.requires_grad_(False)

        pipe = TryonPipeline.from_pretrained(
            HF_MODEL,
            unet=unet,
            vae=vae,
            feature_extractor=CLIPImageProcessor(),
            text_encoder=text_encoder_one,
            text_encoder_2=text_encoder_two,
            tokenizer=tokenizer_one,
            tokenizer_2=tokenizer_two,
            scheduler=noise_scheduler,
            image_encoder=image_encoder,
            torch_dtype=dtype,
        )
        pipe.unet_encoder = unet_encoder

        parsing_model = Parsing(0)
        openpose_model = OpenPose(0)

        tensor_transform = transforms.Compose(
            [transforms.ToTensor(), transforms.Normalize([0.5], [0.5])]
        )

        _pipeline = {
            "stub": False,
            "device": device,
            "dtype": dtype,
            "pipe": pipe,
            "parsing_model": parsing_model,
            "openpose_model": openpose_model,
            "tensor_transform": tensor_transform,
            "ckpt_dir": ckpt_dir,
        }
        logger.info("IDM-VTON loaded on %s", device)
        return _pipeline
    except Exception as e:
        logger.exception("Failed to load IDM-VTON: %s", e)
        if ALLOW_STUB:
            _pipeline = {"stub": True, "error": str(e)}
            return _pipeline
        raise RuntimeError(
            f"IDM-VTON load failed: {e}. "
            "Ensure HF weights are reachable and ckpt/ (densepose/parsing/openpose) exists."
        ) from e


def _category_key(category: str) -> str:
    c = (category or "upper_body").strip().lower().replace("-", "_")
    if c in {"upper", "top", "tops", "upper_body"}:
        return "upper_body"
    if c in {"lower", "bottom", "bottoms", "lower_body"}:
        return "lower_body"
    if c in {"dress", "dresses", "full", "full_body"}:
        return "dresses"
    return "upper_body"


def run_tryon(
    person_b64: str,
    garment_b64: str,
    *,
    category: str = "upper_body",
    garment_description: str = "",
) -> TryOnResult:
    """Run virtual try-on. Raises on failure unless ALLOW_STUB=1."""
    person = _b64_to_pil(person_b64)
    garment = _b64_to_pil(garment_b64)
    pipe_state = load_pipeline()

    if pipe_state.get("stub"):
        return _stub_composite(person, garment)

    import torch
    from typing import List

    from detectron2.data.detection_utils import convert_PIL_to_numpy, _apply_exif_orientation
    from torchvision.transforms.functional import to_pil_image
    from utils_mask import get_mask_location
    import apply_net

    device = pipe_state["device"]
    pipe = pipe_state["pipe"]
    parsing_model = pipe_state["parsing_model"]
    openpose_model = pipe_state["openpose_model"]
    tensor_transform = pipe_state["tensor_transform"]
    cat = _category_key(category)
    desc = (garment_description or cat.replace("_", " ")).strip()

    # Diffusion on CUDA; OpenPose forced to CPU in image patch; DensePose on CPU.
    if device.startswith("cuda"):
        cap = torch.cuda.get_device_capability(0)
        logger.info(
            "cuda device=%s capability=%s torch=%s",
            torch.cuda.get_device_name(0),
            cap,
            torch.__version__,
        )
        smoke = torch.randn(32, 32, device=device, dtype=torch.float16)
        _ = smoke @ smoke
        torch.cuda.synchronize()
        logger.info("cuda fp16 matmul smoke ok")

    pipe.to(device)
    pipe.unet_encoder.to(device)
    logger.info("pipeline moved to %s", device)

    garm_img = garment.convert("RGB").resize((768, 1024))
    human_img = person.convert("RGB").resize((768, 1024))

    logger.info("openpose...")
    keypoints = openpose_model(human_img.resize((384, 512)))
    logger.info("parsing...")
    model_parse, _ = parsing_model(human_img.resize((384, 512)))
    mask, _mask_gray = get_mask_location("hd", cat, model_parse, keypoints)
    mask = mask.resize((768, 1024))

    human_img_arg = _apply_exif_orientation(human_img.resize((384, 512)))
    human_img_arg = convert_PIL_to_numpy(human_img_arg, format="BGR")
    densepose_ckpt = os.path.join(
        pipe_state["ckpt_dir"], "densepose", "model_final_162be9.pkl"
    )
    # DensePose detectron2 ops often hit "no kernel image" on Serverless GPUs.
    logger.info("densepose (cpu)...")
    args = apply_net.create_argument_parser().parse_args(
        (
            "show",
            "./configs/densepose_rcnn_R_50_FPN_s1x.yaml",
            densepose_ckpt,
            "dp_segm",
            "-v",
            "--opts",
            "MODEL.DEVICE",
            "cpu",
        )
    )
    pose_img = args.func(args, human_img_arg)
    pose_img = pose_img[:, :, ::-1]
    pose_img = Image.fromarray(pose_img).resize((768, 1024))

    logger.info("diffusion...")
    with torch.no_grad():
        with torch.cuda.amp.autocast(enabled=device.startswith("cuda")):
            prompt = "model is wearing " + desc
            negative_prompt = (
                "monochrome, lowres, bad anatomy, worst quality, low quality"
            )
            (
                prompt_embeds,
                negative_prompt_embeds,
                pooled_prompt_embeds,
                negative_pooled_prompt_embeds,
            ) = pipe.encode_prompt(
                prompt,
                num_images_per_prompt=1,
                do_classifier_free_guidance=True,
                negative_prompt=negative_prompt,
            )

            prompt_c = "a photo of " + desc
            if not isinstance(prompt_c, List):
                prompt_c = [prompt_c]
            neg_c = [negative_prompt]
            (prompt_embeds_c, _, _, _) = pipe.encode_prompt(
                prompt_c,
                num_images_per_prompt=1,
                do_classifier_free_guidance=False,
                negative_prompt=neg_c,
            )

            pose_t = tensor_transform(pose_img).unsqueeze(0).to(device, torch.float16)
            garm_t = tensor_transform(garm_img).unsqueeze(0).to(device, torch.float16)
            generator = (
                torch.Generator(device).manual_seed(SEED) if SEED >= 0 else None
            )
            images = pipe(
                prompt_embeds=prompt_embeds.to(device, torch.float16),
                negative_prompt_embeds=negative_prompt_embeds.to(device, torch.float16),
                pooled_prompt_embeds=pooled_prompt_embeds.to(device, torch.float16),
                negative_pooled_prompt_embeds=negative_pooled_prompt_embeds.to(
                    device, torch.float16
                ),
                num_inference_steps=DENOISE_STEPS,
                generator=generator,
                strength=1.0,
                pose_img=pose_t,
                text_embeds_cloth=prompt_embeds_c.to(device, torch.float16),
                cloth=garm_t,
                mask_image=mask,
                image=human_img,
                height=1024,
                width=768,
                ip_adapter_image=garm_img.resize((768, 1024)),
                guidance_scale=2.0,
            )[0]

    out = images[0]
    png = _pil_to_png_bytes(out)
    return TryOnResult(image_png=png, width=out.width, height=out.height, stub=False)
