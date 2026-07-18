"""
Multi-provider vision tool for the tunan:vision skill.

Usage:
    uv run vision.py [--provider <name>] <image_path> <prompt>

`uv run` reads the PEP 723 dependency block below and auto-installs
openai into an ephemeral environment — no manual install, no global
pollution. A bare `python vision.py` also works if openai is already
on the path.

Providers: doubao (豆包 / 字节跳动 Volcengine Ark), qwen (通义千问),
openai (GPT-4o), siliconflow (硅基流动), or any OpenAI-compatible endpoint.

API keys are resolved from real environment variables first, then from
a ~/.env file (zero-dependency loader), so you can configure once without
touching settings.json. Real env vars win over ~/.env.

Set one of: ARK_API_KEY (or BD_API_KEY / DOUBAO_API_KEY), DASHSCOPE_API_KEY, OPENAI_API_KEY,
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
        # 豆包 / 字节跳动 Volcengine Ark — OpenAI 兼容。
        # key 优先读 ARK_API_KEY（方舟平台标准密钥），BD_API_KEY、
        # DOUBAO_API_KEY 作为旧名向后兼容。
        "key_envs": ["ARK_API_KEY", "BD_API_KEY", "DOUBAO_API_KEY"],
        "base_env": "DOUBAO_BASE_URL",
        "base_default": "https://ark.cn-beijing.volces.com/api/v3",
        "model_default": "doubao-seed-2-1-pro-260628",
    },
    "qwen": {
        "key_envs": ["DASHSCOPE_API_KEY"],
        "base_env": "DASHSCOPE_BASE_URL",
        "base_default": "https://dashscope.aliyuncs.com/compatible-mode/v1",
        "model_default": "qwen-vl-max",
    },
    "openai": {
        "key_envs": ["OPENAI_API_KEY"],
        "base_env": "OPENAI_BASE_URL",
        "base_default": "https://api.openai.com/v1",
        "model_default": "gpt-4o",
    },
    "siliconflow": {
        # 硅基流动 (SiliconFlow) — OpenAI 兼容的国内模型聚合平台,
        # 视觉模型可在 SILICONFLOW_MODEL 切换: Qwen/Qwen2.5-VL-72B-Instruct,
        # Qwen/Qwen2-VL-72B-Instruct, deepseek-ai/deepseek-vl2 等。
        "key_envs": ["SILICONFLOW_API_KEY"],
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
# Tracks the line number of each key in the .env file so auto-detection
# can prefer the provider whose API key appears earliest in the file.
_key_order: dict[str, int] = {}  # key_name -> 1-based line number


def load_dotenv(path: Path) -> None:
    """Load KEY=VALUE pairs from a .env file. Never overrides real env vars.

    Also populates _key_order so resolve_provider can pick the provider
    whose key appears first in the file — the user controls priority by
    reordering lines in ~/.env.
    """
    global _key_order
    _key_order.clear()
    if not path.is_file():
        return
    try:
        text = path.read_text(encoding="utf-8")
    except (PermissionError, OSError) as e:
        print(f"Warning: cannot read env file {path}: {e}", file=sys.stderr)
        return
    line_num = 0
    for line in text.splitlines():
        line_num += 1
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        key = key.strip()
        val = val.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = val
        # Record the first occurrence of each key (duplicate keys later in
        # the file are ignored — first write wins for ordering).
        if key and key not in _key_order:
            _key_order[key] = line_num


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

    # auto-detect: prefer the provider whose API key appears earliest
    # in the ~/.env file. Keys set only via real env vars (not in the
    # file) sort after file-based keys. Fall back to doubao if nothing
    # is configured.
    candidates = []
    for pname, pconf in PROVIDERS.items():
        set_keys = [k for k in pconf["key_envs"] if os.environ.get(k)]
        if not set_keys:
            continue
        # Earliest line number among this provider's keys in the .env file.
        # float('inf') means the key was set via a real env var, not .env.
        earliest = min(_key_order.get(k, float('inf')) for k in set_keys)
        candidates.append((earliest, pname, pconf))

    if candidates:
        candidates.sort(key=lambda x: x[0])
        return candidates[0][1], candidates[0][2]

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
    api_key = ""
    matched_key = ""
    for k in config["key_envs"]:
        v = os.environ.get(k, "")
        if v:
            api_key = v
            matched_key = k
            break
    if not api_key:
        names = " or ".join(config["key_envs"])
        print(f"Error: {names} env var is not set", file=sys.stderr)
        sys.exit(1)

    # Warn when multiple key_envs are set for a provider (e.g. both
    # BD_API_KEY and DOUBAO_API_KEY) — the first match wins silently.
    if len(config["key_envs"]) > 1:
        others = [k for k in config["key_envs"] if k != matched_key and os.environ.get(k, "")]
        if others:
            print(f"Warning: {matched_key} selected for provider '{provider_name}'; "
                  f"also set: {', '.join(others)}", file=sys.stderr)

    model = resolve_model(provider_name, config)
    base_url = os.environ.get(config["base_env"], config["base_default"])
    temperature = float(os.environ.get("VISION_TEMPERATURE", "0"))
    max_tokens = int(os.environ.get("VISION_MAX_TOKENS", "4096"))

    ext = Path(image_path).suffix.lower()
    mime = MIME_MAP.get(ext)
    if mime is None:
        mime = "image/png"
        print(f"Warning: unknown extension '{ext}' — assuming image/png. "
              f"Supported: {', '.join(MIME_MAP)}", file=sys.stderr)
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
        print(f"Error [{type(e).__name__}]: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
