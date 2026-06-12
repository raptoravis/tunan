#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ds_vision_mcp — 给纯文本模型(如 DeepSeek)补上"看图"能力的极简 MCP server。

设计要点(参考 CSDN 文章 161570507):
  * 零三方依赖: 只用 Python 标准库 + 系统自带的 curl.exe 发 HTTP 请求,
    彻底绕过 Anaconda/conda 自带 OpenSSL 与某些证书链不兼容的问题。
  * OpenAI 兼容: 任何提供 /chat/completions 且支持 image_url 的视觉端点都能接,
    base_url / api_key / model 全部走环境变量,默认指向小米 MiMo。
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
# 配置
# --------------------------------------------------------------------------- #
def _load_dotenv():
    """把 home 目录下的 ~/.env 加载进环境变量(零依赖,已存在的真实环境变量优先)。

    支持: KEY=VALUE / KEY="VALUE" / KEY='VALUE'、# 注释、可选的 export 前缀。
    路径可用 DS_VISION_ENV_FILE 覆盖。
    """
    path = os.environ.get("DS_VISION_ENV_FILE") or os.path.join(
        os.path.expanduser("~"), ".env"
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
                # 真实环境变量优先,不覆盖
                if key and key not in os.environ:
                    os.environ[key] = val
    except OSError:
        pass


def _get_config():
    """从环境变量读取后端配置。默认指向小米 MiMo(OpenAI 兼容端点)。"""
    _load_dotenv()
    base_url = os.environ.get(
        "DS_VISION_BASE_URL", "https://api.mimo.xiaomi.com/v1"
    ).rstrip("/")
    return {
        "api_key": os.environ.get("DS_VISION_API_KEY", ""),
        "base_url": base_url,
        "model": os.environ.get("DS_VISION_MODEL", "mimo-v2.5"),
        # 整体超时(秒),交给 curl 控制
        "timeout": int(os.environ.get("DS_VISION_TIMEOUT", "120")),
    }


# --------------------------------------------------------------------------- #
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
            "未设置 DS_VISION_API_KEY 环境变量,无法调用视觉模型。"
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
                "serverInfo": {"name": "ds_vision_mcp", "version": "0.1.0"},
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
