#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ds_vision_mcp — 给纯文本模型(如 DeepSeek)补上"看图"能力的极简 MCP server。

设计要点(参考 CSDN 文章 161570507):
  * 零三方依赖: 只用 Python 标准库 + 系统自带的 curl.exe 发 HTTP 请求,
    彻底绕过 Anaconda/conda 自带 OpenSSL 与某些证书链不兼容的问题。
  * OpenAI 兼容: 任何提供 /chat/completions 且支持 image_url 的视觉端点都能接,
     base_url / api_key / model 全部走环境变量。
   * 多提供者: 与 tunan:vision skill 共用 ~/.env,自动识别 doubao / qwen /
     openai / siliconflow 四个提供者,也支持 VISION_PROVIDER 显式选择。
  * stdio JSON-RPC: 标准 MCP over stdio,逐行读 stdin、逐行写 stdout。

对外暴露一个工具: describe_image(image_path, prompt?)
"""

import sys
import os
import io
import json
import base64
import mimetypes
import subprocess
import shutil

# 让 Windows 控制台下的 stdout/stdin 走 UTF-8,避免中文乱码 / 编码异常
sys.stdin = io.TextIOWrapper(sys.stdin.buffer, encoding="utf-8")
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", write_through=True)


# --------------------------------------------------------------------------- #
# 提供者注册表(与 skills/vision/scripts/vision.py 的 PROVIDERS 对齐)
# --------------------------------------------------------------------------- #
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
        "key_env": "SILICONFLOW_API_KEY",
        "base_env": "SILICONFLOW_BASE_URL",
        "base_default": "https://api.siliconflow.cn/v1",
        "model_default": "Qwen/Qwen2.5-VL-72B-Instruct",
    },
}

# --------------------------------------------------------------------------- #
# 配置
# --------------------------------------------------------------------------- #
def _load_dotenv():
    """把 ~/.env 加载进环境变量(与 vision skill 共用的零依赖 loader)。

    支持: KEY=VALUE / KEY="VALUE" / KEY='VALUE'、# 注释、export 前缀。
    路径: VISION_ENV_FILE(与 vision skill 统一)或 DS_VISION_ENV_FILE(兼容旧版),
    默认 ~/.env。真实环境变量优先,不覆盖。
    """
    path = (
        os.environ.get("DS_VISION_ENV_FILE")
        or os.environ.get("VISION_ENV_FILE")
        or os.path.join(os.path.expanduser("~"), ".env")
    )
    if not os.path.isfile(path):
        return
    try:
        with open(path, "r", encoding="utf-8") as f:
            for raw in f:
                line = raw.strip()
                if not line or line.startswith("#"):
                    continue
                if line.startswith("export "):
                    line = line[len("export "):].lstrip()
                if "=" not in line:
                    continue
                key, val = line.split("=", 1)
                key = key.strip()
                val = val.strip()
                if (len(val) >= 2) and val[0] == val[-1] and val[0] in "\"'":
                    val = val[1:-1]
                if key and key not in os.environ:
                    os.environ[key] = val
    except OSError:
        pass


def _resolve_model(provider_name, config):
    """按优先级解析模型: VISION_MODEL(全局) > {PROVIDER}_MODEL > 内置默认。"""
    global_model = os.environ.get("VISION_MODEL", "")
    if global_model:
        return global_model
    provider_model_env = f"{provider_name.upper()}_MODEL"
    provider_model = os.environ.get(provider_model_env, "")
    if provider_model:
        return provider_model
    return config["model_default"]


def _resolve_provider_config():
    """按优先级解析提供者配置。

    优先级:
      DS_VISION_*        显式覆盖,可指向任意 OpenAI 兼容端点(最高,兼容旧版)
      VISION_PROVIDER    指定提供者(doubao | qwen | openai | siliconflow)
      自动检测           第一个有 *_API_KEY 的提供者
      内置默认           SiliconFlow(无 key 时后续调用会报明确错误)
    """
    _load_dotenv()

    # (1) DS_VISION_* explicit override (highest priority)
    ds_api_key = os.environ.get("DS_VISION_API_KEY", "")
    if ds_api_key:
        return {
            "api_key": ds_api_key,
            "base_url": os.environ.get(
                "DS_VISION_BASE_URL", "https://api.siliconflow.cn/v1"
            ).rstrip("/"),
            "model": os.environ.get(
                "DS_VISION_MODEL", "Qwen/Qwen2.5-VL-72B-Instruct"
            ),
        }

    # (2) VISION_PROVIDER (shared with vision skill)
    env_provider = os.environ.get("VISION_PROVIDER", "").lower()
    if env_provider:
        if env_provider not in PROVIDERS:
            available = ", ".join(PROVIDERS)
            raise RuntimeError(
                f"VISION_PROVIDER='{env_provider}' 不是有效的提供者(可用: {available})"
            )
        p = PROVIDERS[env_provider]
        api_key = os.environ.get(p["key_env"], "")
        if not api_key:
            raise RuntimeError(
                f"VISION_PROVIDER={env_provider},但 {p['key_env']} 未设置。"
                f"请在 ~/.env 中配置该 key,或更改 VISION_PROVIDER。"
            )
        return {
            "api_key": api_key,
            "base_url": os.environ.get(p["base_env"], p["base_default"]).rstrip("/"),
            "model": _resolve_model(env_provider, p),
        }

    # (3) auto-detect: first provider with an API key set
    for pname, pconf in PROVIDERS.items():
        api_key = os.environ.get(pconf["key_env"], "")
        if api_key:
            return {
                "api_key": api_key,
                "base_url": os.environ.get(
                    pconf["base_env"], pconf["base_default"]
                ).rstrip("/"),
                "model": _resolve_model(pname, pconf),
            }

    # (4) fallback (no key -- call_vision will error with a clear message)
    return {
        "api_key": "",
        "base_url": "https://api.siliconflow.cn/v1",
        "model": "Qwen/Qwen2.5-VL-72B-Instruct",
    }


def _get_config():
    """从环境变量读取后端配置(与 vision skill 共用 ~/.env)。"""
    cfg = _resolve_provider_config()
    return {
        "api_key": cfg["api_key"],
        "base_url": cfg["base_url"],
        "model": cfg["model"],
        "timeout": int(os.environ.get("DS_VISION_TIMEOUT", "120")),
    }

# 图片 -> base64 data URL
# --------------------------------------------------------------------------- #
def encode_image(image_path):
    """把本地图片读成 data:<mime>;base64,<...> 形式的 URL。"""
    if not os.path.isfile(image_path):
        raise FileNotFoundError(f"找不到图片: {image_path}")

    mime, _ = mimetypes.guess_type(image_path)
    if not mime or not mime.startswith("image/"):
        # 兜底:按扩展名猜,再不行当 png
        ext = os.path.splitext(image_path)[1].lower().lstrip(".")
        mime = f"image/{ext}" if ext else "image/png"

    with open(image_path, "rb") as f:
        data = base64.b64encode(f.read()).decode("ascii")
    return f"data:{mime};base64,{data}"


# --------------------------------------------------------------------------- #
# 调用视觉模型(走 curl.exe,绕过 Python 的 SSL)
# --------------------------------------------------------------------------- #
def _curl_bin():
    """定位 curl 可执行文件。Win10+ 自带 curl.exe。"""
    return shutil.which("curl") or shutil.which("curl.exe") or "curl"


def call_vision(image_path, prompt):
    cfg = _get_config()
    if not cfg["api_key"]:
        raise RuntimeError(
            "未设置视觉模型 API key:请在 ~/.env 写入 DOUBAO_API_KEY / "
            "DASHSCOPE_API_KEY / OPENAI_API_KEY / SILICONFLOW_API_KEY 之一,"
            "或用 DS_VISION_API_KEY 显式覆盖。详见 skills/vision/.env.example。"
        )

    data_url = encode_image(image_path)
    payload = {
        "model": cfg["model"],
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image_url", "image_url": {"url": data_url}},
                ],
            }
        ],
    }

    url = f"{cfg['base_url']}/chat/completions"
    # 用 --data-binary @- 从 stdin 喂 body,避免超长命令行 / 转义问题
    args = [
        _curl_bin(),
        "-sS",
        "--fail-with-body",
        "--max-time", str(cfg["timeout"]),
        "-X", "POST", url,
        "-H", "Content-Type: application/json",
        "-H", f"Authorization: Bearer {cfg['api_key']}",
        "--data-binary", "@-",
    ]

    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    proc = subprocess.run(
        args, input=body, stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    out = proc.stdout.decode("utf-8", "replace")
    err = proc.stderr.decode("utf-8", "replace")

    if proc.returncode != 0:
        raise RuntimeError(
            f"curl 调用失败 (code={proc.returncode})\n"
            f"stderr: {err.strip()}\nbody: {out.strip()}"
        )

    try:
        resp = json.loads(out)
    except json.JSONDecodeError:
        raise RuntimeError(f"无法解析响应为 JSON:\n{out[:2000]}")

    if "error" in resp:
        raise RuntimeError(f"API 返回错误: {json.dumps(resp['error'], ensure_ascii=False)}")

    try:
        return resp["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError):
        raise RuntimeError(f"响应结构异常:\n{json.dumps(resp, ensure_ascii=False)[:2000]}")


# --------------------------------------------------------------------------- #
# MCP 协议处理
# --------------------------------------------------------------------------- #
PROTOCOL_VERSION = "2024-11-05"

TOOLS = [
    {
        "name": "describe_image",
        "description": (
            "识别/描述一张本地图片。把图片发给视觉模型并返回文字描述,"
            "可用于截图分析、报错图、UI、图表、照片等。"
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "image_path": {
                    "type": "string",
                    "description": "本地图片的绝对路径,如 C:\\\\shots\\\\error.png",
                },
                "prompt": {
                    "type": "string",
                    "description": "可选。希望模型如何看这张图(默认:详细描述图片内容)。",
                },
            },
            "required": ["image_path"],
        },
    }
]


def handle_request(req):
    """处理单条 JSON-RPC 请求,返回 response dict(通知则返回 None)。"""
    method = req.get("method")
    req_id = req.get("id")

    def ok(result):
        return {"jsonrpc": "2.0", "id": req_id, "result": result}

    def fail(code, message):
        return {"jsonrpc": "2.0", "id": req_id, "error": {"code": code, "message": message}}

    if method == "initialize":
        return ok(
            {
                "protocolVersion": PROTOCOL_VERSION,
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "ds_vision_mcp", "version": "0.2.0"},
            }
        )

    if method in ("notifications/initialized", "initialized"):
        return None  # 通知,无需回复

    if method == "tools/list":
        return ok({"tools": TOOLS})

    if method == "tools/call":
        params = req.get("params", {})
        name = params.get("name")
        args = params.get("arguments", {}) or {}
        if name != "describe_image":
            return fail(-32602, f"未知工具: {name}")

        image_path = args.get("image_path")
        prompt = args.get("prompt") or "请详细描述这张图片的内容。如有文字请原样转录。"
        if not image_path:
            return fail(-32602, "缺少必填参数 image_path")

        try:
            text = call_vision(image_path, prompt)
            return ok({"content": [{"type": "text", "text": text}]})
        except Exception as e:  # 工具级错误:用 isError 返回,而非协议错误
            return ok(
                {
                    "content": [{"type": "text", "text": f"识图失败: {e}"}],
                    "isError": True,
                }
            )

    if method == "ping":
        return ok({})

    return fail(-32601, f"未实现的 method: {method}")


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except json.JSONDecodeError:
            continue

        resp = handle_request(req)
        if resp is not None:
            sys.stdout.write(json.dumps(resp, ensure_ascii=False) + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    main()
