"""
Multi-provider vision tool for the tunan:vision skill.

Usage:
    uv run vision.py [--provider <name>] <image_path> <prompt>

`uv run` reads the PEP 723 dependency block below and auto-installs
openai into an ephemeral environment — no manual install, no global
pollution. A bare `python vision.py` also works if openai is already
on the path.

Providers: doubao (豆包), qwen (通义千问), openai (GPT-4o),
siliconflow (硅基流动), or any OpenAI-compatible endpoint.

API keys are resolved from real environment variables first, then from
a ~/.env file (zero-dependency loader), so you can configure once without
touching settings.json. Real env vars win over ~/.env.

Set one of: DOUBAO_API_KEY, DASHSCOPE_API_KEY, OPENAI_API_KEY,
SILICONFLOW_API_KEY
"""
# /// script
# requires-python = ">=3.8"
# dependencies = [
#     "openai>=1.0.0",
# ]
# ///
import sys
import os
import base64
import argparse
from pathlib import Path

if sys.platform == "win32" and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


def _get_openai_client(api_key: str, base_url: str):
    """Lazy-import openai so --help / arg validation work without the dep."""
    try:
        from openai import OpenAI
    except ImportError:
        print(
            "Error: openai package is not installed. Run via uv (auto-installs "
            "the dependency from the PEP 723 block):\n"
            "  uv run scripts/vision.py ...\n"
            "or install it manually:\n"
            "  uv pip install openai",
            file=sys.stderr,
        )
        sys.exit(1)
    return OpenAI(api_key=api_key, base_url=base_url)


# ── provider registry ──────────────────────────────────────────────
PROVIDERS = {
    "doubao": {
        "key_env": "DOUBAO_API_KEY",
        "base_env": "DOUBAO_BASE_URL",
        "base_default": "https://ark.cn-beijing.volces.com/api/v3",
        "model_default": "doubao-seed-2-0-pro-260215",
    },
    "qwen": {
        "key_env": "DASHSCOPE_API_KEY",
        "base_env": "DASHSCOPE_BASE_URL",
        "base_default": "https://dashscope.aliyuncs.com/compatible-mode/v1",
        "model_default": "qwen-vl-max",
    },
    "openai": {
        "key_env": "OPENAI_API_KEY",
        "base_env": "OPENAI_BASE_URL",
        "base_default": "https://api.openai.com/v1",
        "model_default": "gpt-4o",
    },
    "siliconflow": {
        # 硅基流动 (SiliconFlow) — OpenAI 兼容的国内模型聚合平台,
        # 视觉模型可在 SILICONFLOW_MODEL 切换: Qwen/Qwen2.5-VL-72B-Instruct,
        # Qwen/Qwen2-VL-72B-Instruct, deepseek-ai/deepseek-vl2 等。
        "key_env": "SILICONFLOW_API_KEY",
        "base_env": "SILICONFLOW_BASE_URL",
        "base_default": "https://api.siliconflow.cn/v1",
        "model_default": "Qwen/Qwen2.5-VL-72B-Instruct",
    },
}

MIME_MAP = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".webp": "image/webp",
    ".gif": "image/gif",
}


# ── ~/.env loader (zero-dependency, real env wins) ─────────────────
def load_dotenv(path: Path) -> None:
    """Load KEY=VALUE pairs from a .env file. Never overrides real env vars."""
    if not path.is_file():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        key = key.strip()
        val = val.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = val


# ── helpers ─────────────────────────────────────────────────────────
def encode_image(path: str) -> str:
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


def resolve_provider(name: str | None) -> tuple[str, dict]:
    # explicit --provider flag
    if name:
        if name not in PROVIDERS:
            names = ", ".join(PROVIDERS)
            print(f"Error: unknown provider '{name}'. Available: {names}", file=sys.stderr)
            sys.exit(1)
        return name, PROVIDERS[name]

    # VISION_PROVIDER env var
    env_provider = os.environ.get("VISION_PROVIDER", "").lower()
    if env_provider:
        if env_provider not in PROVIDERS:
            names = ", ".join(PROVIDERS)
            print(f"Error: VISION_PROVIDER='{env_provider}' is invalid. Available: {names}", file=sys.stderr)
            sys.exit(1)
        return env_provider, PROVIDERS[env_provider]

    # auto-detect: first provider whose API key is set
    for pname, pconf in PROVIDERS.items():
        if os.environ.get(pconf["key_env"]):
            return pname, pconf

    return "doubao", PROVIDERS["doubao"]


def resolve_model(provider_name: str, config: dict) -> str:
    # VISION_MODEL (global override, highest priority)
    global_model = os.environ.get("VISION_MODEL", "")
    if global_model:
        return global_model

    # provider-specific env: {PROVIDER}_MODEL
    provider_model_env = f"{provider_name.upper()}_MODEL"
    provider_model = os.environ.get(provider_model_env, "")
    if provider_model:
        return provider_model

    return config["model_default"]


# ── main ────────────────────────────────────────────────────────────
def vision(image_path: str, prompt: str, provider_name: str, config: dict) -> str:
    api_key = os.environ.get(config["key_env"], "")
    if not api_key:
        print(f"Error: {config['key_env']} env var is not set", file=sys.stderr)
        sys.exit(1)

    model = resolve_model(provider_name, config)
    base_url = os.environ.get(config["base_env"], config["base_default"])
    temperature = float(os.environ.get("VISION_TEMPERATURE", "0"))
    max_tokens = int(os.environ.get("VISION_MAX_TOKENS", "4096"))

    ext = Path(image_path).suffix.lower()
    mime = MIME_MAP.get(ext, "image/png")
    b64 = encode_image(image_path)
    data_uri = f"data:{mime};base64,{b64}"

    client = _get_openai_client(api_key, base_url)
    resp = client.chat.completions.create(
        model=model,
        messages=[
            {
                "role": "user",
                "content": [
                    {"type": "image_url", "image_url": {"url": data_uri}},
                    {"type": "text", "text": prompt},
                ],
            }
        ],
        temperature=temperature,
        max_tokens=max_tokens,
    )
    return resp.choices[0].message.content or ""


# ── cli ─────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="Multi-provider vision tool")
    parser.add_argument("--provider", "-p", choices=list(PROVIDERS), default=None,
                        help="Vision model provider (auto-detected from env if omitted)")
    parser.add_argument("image_path", help="Path to the image file")
    parser.add_argument("prompt", help="Text prompt for the vision model")
    args = parser.parse_args()

    # load ~/.env (real env still wins) — VISION_ENV_FILE overrides the path
    env_file = os.environ.get("VISION_ENV_FILE", str(Path.home() / ".env"))
    load_dotenv(Path(env_file))

    if not os.path.exists(args.image_path):
        print(f"Error: file not found: {args.image_path}", file=sys.stderr)
        sys.exit(1)

    provider_name, config = resolve_provider(args.provider)

    try:
        result = vision(args.image_path, args.prompt, provider_name, config)
        print(result)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
