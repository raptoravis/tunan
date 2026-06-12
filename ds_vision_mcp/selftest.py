#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ds_vision_mcp 本地自检:校验协议处理 + base64 编码,不打真实 API。"""

import os
import sys
import base64

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import server  # noqa: E402


def check(name, cond):
    print(("  PASS " if cond else "  FAIL ") + name)
    assert cond, name


print("[1] initialize")
r = server.handle_request({"jsonrpc": "2.0", "id": 1, "method": "initialize"})
check("serverInfo.name == ds_vision_mcp", r["result"]["serverInfo"]["name"] == "ds_vision_mcp")
check("has protocolVersion", "protocolVersion" in r["result"])

print("[2] notifications/initialized -> 无回复")
r = server.handle_request({"jsonrpc": "2.0", "method": "notifications/initialized"})
check("returns None", r is None)

print("[3] tools/list")
r = server.handle_request({"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
tools = r["result"]["tools"]
check("暴露 describe_image", any(t["name"] == "describe_image" for t in tools))
check("image_path 必填", "image_path" in tools[0]["inputSchema"]["required"])

print("[4] tools/call 缺参数 -> 协议错误")
r = server.handle_request(
    {"jsonrpc": "2.0", "id": 3, "method": "tools/call",
     "params": {"name": "describe_image", "arguments": {}}}
)
check("返回 error", "error" in r)

print("[5] encode_image base64 往返")
png = bytes.fromhex(
    "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4"
    "890000000a49444154789c6360000002000154a24f1f0000000049454e44ae426082"
)
tmp = os.path.join(os.path.dirname(__file__), "_selftest.png")
with open(tmp, "wb") as f:
    f.write(png)
try:
    url = server.encode_image(tmp)
    check("是 png data url", url.startswith("data:image/png;base64,"))
    decoded = base64.b64decode(url.split(",", 1)[1])
    check("解码后字节一致", decoded == png)
finally:
    os.remove(tmp)

print("[6] tools/call 找不到图片 -> isError(工具级)")
r = server.handle_request(
    {"jsonrpc": "2.0", "id": 4, "method": "tools/call",
     "params": {"name": "describe_image",
                "arguments": {"image_path": "C:/nope/missing_____.png"}}}
)
check("result.isError == True", r["result"].get("isError") is True)

print("\n全部自检通过 ✅")
