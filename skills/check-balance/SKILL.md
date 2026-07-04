---
name: check-balance
description: "Check LLM provider connectivity and account balance from API keys in ~/.env. Use when onboarding a new key, before a long-running job that needs guaranteed quota, after an auth/401 failure, or when auditing which providers are still funded. Reads SILICONFLOW_API_KEY, DEEPSEEK_API_KEY, DASHSCOPE_API_KEY, OPENAI_API_KEY, DOUBAO_API_KEY from ~/.env (real env vars win over the file). Reports remaining balance for providers that expose it (SiliconFlow, DeepSeek) and connectivity-only for the rest (DashScope, OpenAI, Doubao — their sk- keys cannot query billing). Zero third-party deps — uses stdlib + system curl."
---

# check-balance

One-shot health + balance report for every LLM provider configured in `~/.env`. Tells you which keys work and how much credit remains — before you kick off a long run and discover mid-way that a key is out of quota.

## Quick start

```bash
python "${CLAUDE_SKILL_DIR}/scripts/check_balance.py"
```

Zero dependencies (pure stdlib + system `curl`, same SSL-bypass approach as `ds_vision_mcp`) — no `uv`/`pip` needed. Just run it.

Output (table by default):

```
# Provider   # Status  # Balance  # Detail                 # Key
-----------  --------  ---------  -----------------------  -----
siliconflow  ✓ OK      ¥15.31     充值 15.31 · 赠送 0          njvq
deepseek     ✓ OK      ¥4840.52   充值 4840.52 · 赠送 0.00    37b9
dashscope    ✓ OK      —          无余额 API(仅测连通)          1325

3/3 provider 连通。
```

Exit code is `0` only when every checked provider is reachable — use it as a gate in scripts/CI.

## Options

```bash
# Only check specific provider(s) (repeatable)
python "${CLAUDE_SKILL_DIR}/scripts/check_balance.py" -p deepseek -p siliconflow

# Machine-readable JSON
python "${CLAUDE_SKILL_DIR}/scripts/check_balance.py" --json

# Ignore ~/.env, use only real environment variables
python "${CLAUDE_SKILL_DIR}/scripts/check_balance.py" --no-env
```

`--json` emits a list of `{provider, ok, http, balance, error, key_tail}` objects.

## What it checks per provider

| Provider | Connectivity | Balance | Notes |
|----------|--------------|---------|-------|
| siliconflow | `GET /v1/user/info` | ✓ totalBalance | chargeBalance / granted split shown |
| deepseek | `GET /user/balance` | ✓ total_balance | currency-aware (CNY/USD) |
| dashscope | `GET /v1/models` | — | Aliyun billing needs BSS OpenAPI + AK/SK, not the sk- key |
| openai | `GET /v1/models` | — | Needs dashboard/org key, not sk- |
| doubao | `GET /v1/models` | — | Volcengine billing needs signed AK/SK |

Providers without an API key in `~/.env` are silently skipped (not failures).

## Configuration

Keys live in `~/.env` (i.e. `C:\Users\<you>\.env` on Windows). The script auto-loads it on every run; real environment variables take precedence over the file. Override the file path with `CHECK_BALANCE_ENV_FILE`.

```dotenv
# ~/.env
SILICONFLOW_API_KEY=sk-...
DEEPSEEK_API_KEY=sk-...
DASHSCOPE_API_KEY=sk-...
OPENAI_API_KEY=sk-...
DOUBAO_API_KEY=...
```

## How to read failures

- `✗ FAIL HTTP 401` — key invalid, revoked, or wrong provider
- `✗ FAIL HTTP 403` — key valid but lacks permission for this endpoint
- `✗ FAIL curl 失败` — network/DNS/timeout, or wrong `*_BASE_URL`
- Provider not listed at all — no `*_API_KEY` found in `~/.env` or the environment

## Relationship to other tunan skills

- **`tunan:vision`** / **`ds-vision` MCP** consume these same keys. Run `check-balance` first when a vision call fails with 401 or an out-of-quota error.
- Shares the `~/.env` convention with all tunan LLM tooling — keys configured once.
