# Thin RunPod Serverless wrapper around a prebuilt IDM-VTON image.
# Patch hardcoded /runpod-volume paths — RunPod may mount an empty volume there.
#
# Build:
#   docker build --platform linux/amd64 -t YOURUSER/idm-vton-worker:v8 .

FROM fonixteam/idm-vton:pod-v1

ENV PYTHONUNBUFFERED=1 \
    IDM_ROOT=/IDM-VTON \
    MODEL_DIR=/opt/idm-ckpt \
    BAKED_MODEL_DIR=/opt/idm-ckpt \
    ALLOW_STUB=0 \
    RUNPOD_INIT_TIMEOUT=1200 \
    HF_HOME=/root/.cache/huggingface \
    TRANSFORMERS_CACHE=/root/.cache/huggingface \
    HUGGINGFACE_HUB_CACHE=/root/.cache/huggingface

RUN if [ ! -d /IDM-VTON ] && [ -d /app/IDM-VTON ]; then \
      ln -s /app/IDM-VTON /IDM-VTON; \
    elif [ ! -d /IDM-VTON ] && [ -d /workspace/IDM-VTON ]; then \
      ln -s /workspace/IDM-VTON /IDM-VTON; \
    elif [ ! -d /IDM-VTON ] && [ -d /root/IDM-VTON ]; then \
      ln -s /root/IDM-VTON /IDM-VTON; \
    fi

RUN python -m pip install --no-cache-dir --upgrade pip \
    && python -m pip uninstall -y cryptography 2>/dev/null || true \
    && python -m pip install --no-cache-dir \
        'cryptography>=41.0.0,<45' \
        'paramiko>=3.0.0' \
        'runpod>=1.7.0,<1.8' \
        pillow \
        huggingface_hub \
    && python -c "import runpod, cryptography; print('runpod', getattr(runpod, '__version__', '?'), 'crypto ok')"

# Bake ckpts outside /runpod-volume so a volume mount cannot hide them.
COPY scripts/bake_ckpt.py /tmp/bake_ckpt.py
RUN sed -i 's|/runpod-volume/IDM-VTON/ckpt|/opt/idm-ckpt|g' /tmp/bake_ckpt.py \
    && mkdir -p /opt/idm-ckpt/humanparsing /opt/idm-ckpt/densepose /opt/idm-ckpt/openpose/ckpts \
    && python /tmp/bake_ckpt.py \
    && test -f /opt/idm-ckpt/humanparsing/parsing_atr.onnx \
    && test -f /opt/idm-ckpt/densepose/model_final_162be9.pkl \
    && ls -laR /opt/idm-ckpt

# Patch base-image hardcoded paths to /opt/idm-ckpt
RUN python - <<'PY'
from pathlib import Path
replacements = [
    ("/runpod-volume/IDM-VTON/ckpt", "/opt/idm-ckpt"),
    ("/runpod-volume/IDM-VTON", "/IDM-VTON"),
]
changed = 0
for path in Path("/IDM-VTON").rglob("*.py"):
    try:
        text = path.read_text(encoding="utf-8")
    except Exception:
        continue
    new = text
    for a, b in replacements:
        new = new.replace(a, b)
    if new != text:
        path.write_text(new, encoding="utf-8")
        changed += 1
        print("patched", path)
print("files_patched", changed)
ckpt = Path("/IDM-VTON/ckpt")
if ckpt.is_symlink() or ckpt.exists():
    if ckpt.is_symlink() or ckpt.is_file():
        ckpt.unlink()
    elif ckpt.is_dir() and not any(ckpt.iterdir()):
        ckpt.rmdir()
if not ckpt.exists():
    ckpt.symlink_to("/opt/idm-ckpt")
    print("linked /IDM-VTON/ckpt -> /opt/idm-ckpt")

body = Path("/IDM-VTON/preprocess/openpose/annotator/openpose/body.py")
txt = body.read_text(encoding="utf-8")
# Force OpenPose Body onto CPU — avoids "no kernel image" on mismatched GPU arches.
txt2 = txt.replace(
    """        if torch.cuda.is_available():
            self.model = self.model.cuda()
            # print('cuda')
""",
    """        # DrapeAI: keep OpenPose on CPU for Serverless GPU-arch compatibility
        self.model = self.model.cpu()
""",
)
old_data = """            data = torch.from_numpy(im).float()
            if torch.cuda.is_available():
                data = data.cuda()
"""
new_data = """            data = torch.from_numpy(im).float()
            data = data.to(next(self.model.parameters()).device)
"""
if old_data in txt2:
    txt2 = txt2.replace(old_data, new_data)
elif "data.to(next(self.model.parameters()).device)" not in txt2:
    raise SystemExit("openpose data device patch target not found")
if "self.model = self.model.cpu()" not in txt2:
    raise SystemExit("openpose cpu patch failed")
body.write_text(txt2, encoding="utf-8")
print("patched openpose body -> CPU")
PY

# Base image ships torch 2.0.1+cu117 without sm_89 (Ada). Upgrade so Serverless
# Ada GPUs can run diffusion kernels. Keep detectron2 import-checked.
RUN python -m pip uninstall -y torchaudio 2>/dev/null || true \
    && python -m pip install --no-cache-dir \
      torch==2.1.2 torchvision==0.16.2 \
      --index-url https://download.pytorch.org/whl/cu118 \
    && python - <<'PY'
from pathlib import Path
import torch, detectron2
print("torch", torch.__version__, "cuda", torch.version.cuda)
print("detectron2", detectron2.__version__, "ok")
lib = Path("/usr/local/lib/python3.10/dist-packages/torch/lib/libtorch_cuda.so")
data = lib.read_bytes()
has_ada = (
    data.find(b"sm_89") != -1
    or data.find(b"compute_89") != -1
    or data.find(b"8.9") != -1
)
print("libtorch_has_ada", has_ada)
assert has_ada, "torch wheel missing Ada kernels"
assert data.find(b"sm_80") != -1 and data.find(b"sm_86") != -1, "missing Ampere"
PY

RUN mkdir -p /app
COPY src/handler.py /app/handler.py
COPY src/infer.py /app/infer.py
COPY scripts/find_idm_root.py /app/find_idm_root.py

WORKDIR /app
ENTRYPOINT ["python", "-u", "/app/handler.py"]
