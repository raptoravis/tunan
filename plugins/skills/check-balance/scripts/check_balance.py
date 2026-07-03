#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check-balance — 检查 ~/.env 里各 LLM provider 的连通性与账户余额。

零三方依赖: 纯标准库 + 系统 curl(绕开 Anaconda/conda 的 OpenSSL 证书问题,
与 ds_vision_mcp 同思路)。

  * 连通性: 对每个配置了 key 的 provider 发一个鉴权 GET,判定 key 是否有效、
    端点是否可达。
  * 余额:    暴露了余额 API 的 provider(SiliconFlow、DeepSeek)解析并展示;
    其余(DashScope、OpenAI、Doubao)普通 sk- key 查不了余额,只测连通性。

用法:
    python check_balance.py [--provider <name> ...] [--json] [--no-env]

key 解析顺序: 真实环境变量 > ~/.env 文件(VISION 风格零配置)。
"""
import sys
import os
import json
import argparse
import subprocess
import shutil

if sys.platform == "win32" and hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


# ── provider 注册表 ────────────────────────────────────────────────
# balance_path  : 能查余额的 GET 路径;None 表示无简单余额 API,仅测连通。
# connect_path  : 无余额 API 时用于测连通性的 GET 路径(余额成功则免)。
def _p_siliconflow(d):
    data = d.get("data", d)
    return {
        "total": data.get("totalBalance", "?"),
        "currency": "CNY",
        "detail": f"充值 {data.get('chargeBalance', '?')} · 赠送 {data.get('balance', '?')}",
    }


def _p_deepseek(d):
    infos = d.get("balance_infos") or d.get("balance_accounts") or []
    if not infos:
        return {"total": "?", "currency": "?", "detail": "响应无余额字段"}
    info = infos[0]
    return {
        "total": info.get("total_balance", "?"),
        "currency": info.get("currency", "?"),
        "detail": f"充值 {info.get('topped_up_balance', '?')} · 赠送 {info.get('granted_balance', '?')}",
    }


PROVIDERS = {
    "siliconflow": {
        "key_env": "SILICONFLOW_API_KEY",
        "base_env": "SILICONFLOW_BASE_URL",
        "base_default": "https://api.siliconflow.cn/v1",
        "balance_path": "/user/info",
        "connect_path": None,
        "parse": _p_siliconflow,
    },
    "deepseek": {
        "key_env": "DEEPSEEK_API_KEY",
        "base_env": "DEEPSEEK_BASE_URL",
        "base_default": "https://api.deepseek.com",
        "balance_path": "/user/balance",
        "connect_path": None,
        "parse": _p_deepseek,
    },
    "dashscope": {
        "key_env": "DASHSCOPE_API_KEY",
        "base_env": "DASHSCOPE_BASE_URL",
        "base_default": "https://dashscope.aliyuncs.com/compatible-mode/v1",
        "balance_path": None,  # 需阿里云 BSS OpenAPI + AK/SK,普通 sk- 查不了
        "connect_path": "/models",
        "parse": None,
    },
    "openai": {
        "key_env": "OPENAI_API_KEY",
        "base_env": "OPENAI_BASE_URL",
        "base_default": "https://api.openai.com/v1",
        "balance_path": None,  # 需 dashboard/org key
        "connect_path": "/models",
        "parse": None,
    },
    "doubao": {
        "key_env": "DOUBAO_API_KEY",
        "base_env": "DOUBAO_BASE_URL",
        "base_default": "https://ark.cn-beijing.volces.com/api/v3",
        "balance_path": None,  # 需火山引擎计费 API + AK/SK 签名
        "connect_path": "/models",
        "parse": None,
    },
}


# ── ~/.env 加载(真实环境变量优先) ──────────────────────────────────
def load_dotenv(path):
    if not os.path.isfile(path):
        return
    with open(path, "r", encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            if line.startswith("export "):
                line = line[len("export "):].lstrip()
            key, _, val = line.partition("=")
            key = key.strip()
            val = val.strip()
            if len(val) >= 2 and val[0] == val[-1] and val[0] in "\"'":
                val = val[1:-1]
            if key and key not in os.environ:
                os.environ[key] = val


# ── curl GET ───────────────────────────────────────────────────────
def _curl_bin():
    return shutil.which("curl") or shutil.which("curl.exe") or "curl"


def curl_get_json(url, api_key, timeout=30):
    """带 Bearer 鉴权的 GET,返回 (http_code, parsed_json_or_None, raw_body)。"""
    sep = "\n@@HTTPCODE:"
    proc = subprocess.run(
        [_curl_bin(), "-sS", "--max-time", str(timeout),
         "-o", "-", "-w", sep + "%{http_code}",
         "-H", f"Authorization: Bearer {api_key}", url],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    raw = proc.stdout.decode("utf-8", "replace")
    err = proc.stderr.decode("utf-8", "replace").strip()
    body, _, codepart = raw.rpartition(sep)
    if not codepart:
        # -w 没写入(可能是 curl 早期失败),body 取整段
        body = raw
    try:
        http_code = int(codepart.strip()) if codepart.strip().isdigit() else 0
    except ValueError:
        http_code = 0

    if not body and proc.returncode != 0:
        raise RuntimeError(f"curl 失败 (code={proc.returncode}): {err}")

    try:
        return http_code, json.loads(body), body
    except json.JSONDecodeError:
        return http_code, None, body


# ── 单 provider 检查 ───────────────────────────────────────────────
def check_provider(name, conf):
    key = os.environ.get(conf["key_env"], "")
    base = (os.environ.get(conf["base_env"]) or conf["base_default"]).rstrip("/")
    if not key:
        return None  # 未配置,跳过

    result = {"provider": name, "ok": False, "http": None, "balance": None,
              "error": None, "key_tail": key[-4:] if len(key) >= 4 else "????"}

    path = conf.get("balance_path") or conf.get("connect_path")
    if not path:
        result["error"] = "未配置检查路径"
        return result

    url = base + path
    try:
        http_code, data, body = curl_get_json(url, key)
    except RuntimeError as e:
        result["error"] = str(e)
        return result

    result["http"] = http_code
    if http_code != 200:
        # 把 API 错误信息挖出来
        msg = ""
        if isinstance(data, dict):
            err_obj = data.get("error") or data.get("message") or data.get("msg")
            if isinstance(err_obj, dict):
                msg = err_obj.get("message") or str(err_obj)
            elif err_obj:
                msg = str(err_obj)
        result["error"] = f"HTTP {http_code}" + (f": {msg}" if msg else "")
        return result

    result["ok"] = True
    if conf.get("parse") and isinstance(data, dict):
        try:
            result["balance"] = conf["parse"](data)
        except Exception as e:
            result["balance"] = {"total": "?", "currency": "?", "detail": f"解析失败: {e}"}
    elif not conf.get("balance_path"):
        result["balance"] = {"total": "—", "currency": "",
                             "detail": "无余额 API(仅测连通)"}
    return result


# ── 输出 ───────────────────────────────────────────────────────────
def _money(total, currency):
    if total == "—" or total == "?":
        return total
    cur = currency.upper() if currency else ""
    sym = {"CNY": "¥", "USD": "$"}.get(cur, cur + " " if cur else "")
    return f"{sym}{total}"


def print_table(results):
    configured = [r for r in results if r is not None]
    if not configured:
        print("未检测到任何 provider 的 API key。请在 ~/.env 配置 SILICONFLOW_API_KEY / DEEPSEEK_API_KEY 等。")
        return

    rows = []
    for r in configured:
        if r["ok"]:
            bal = r["balance"] or {}
            status = "✓ OK"
            balance = _money(bal.get("total"), bal.get("currency", ""))
            detail = bal.get("detail", "")
        else:
            status = "✗ FAIL"
            balance = "—"
            detail = r["error"] or "未知错误"
        rows.append((r["provider"], status, balance, detail, r["key_tail"]))

    W = [max(len(str(c[i])) for c in [("# Provider", "# Status", "# Balance", "# Detail", "# Key")] + rows)
         for i in range(5)]
    fmt = "  ".join(f"{{:<{w}}}" for w in W)
    print(fmt.format("# Provider", "# Status", "# Balance", "# Detail", "# Key"))
    print(fmt.format(*["-" * w for w in W]))
    for row in rows:
        print(fmt.format(*row))

    ok = sum(1 for r in configured if r["ok"])
    print(f"\n{ok}/{len(configured)} provider 连通。"
          + ("" if ok == len(configured) else " 失败的请检查 key / 网络 / base_url。"))


# ── cli ────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="检查 ~/.env 里 LLM provider 的连通性与余额")
    parser.add_argument("--provider", "-p", action="append", choices=list(PROVIDERS),
                        help="只检查指定 provider(可重复)。默认检查所有已配置 key 的 provider。")
    parser.add_argument("--json", action="store_true", help="输出 JSON(便于脚本解析)")
    parser.add_argument("--no-env", action="store_true", help="不加载 ~/.env,只用真实环境变量")
    args = parser.parse_args()

    if not args.no_env:
        env_file = os.environ.get("CHECK_BALANCE_ENV_FILE") or os.path.join(os.path.expanduser("~"), ".env")
        load_dotenv(env_file)

    targets = args.provider or list(PROVIDERS)
    results = [check_provider(n, PROVIDERS[n]) for n in targets]

    if args.json:
        out = [r for r in results if r is not None]
        print(json.dumps(out, ensure_ascii=False, indent=2))
        # 任一失败 → 退出码 1(便于 CI / 脚本判断)
        # 未检查到任何已配置 provider(空 out)也算失败,避免 CI gate 误报成功
        sys.exit(0 if out and all(r["ok"] for r in out) else 1)
    else:
        print_table(results)
        configured = [r for r in results if r is not None]
        sys.exit(0 if configured and all(r["ok"] for r in configured) else 1)


if __name__ == "__main__":
    main()
