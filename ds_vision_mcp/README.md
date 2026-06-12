# ds_vision_mcp

给纯文本模型(如 DeepSeek)补上"看图"能力的极简 MCP server。

参考：CSDN《Claude Code + DeepSeek 图片识别方案》。思路是用一个**零三方依赖**的单文件
MCP server，通过系统自带的 `curl.exe` 调用任意 **OpenAI 兼容**的视觉端点(默认小米 MiMo)，
对外暴露 `describe_image` 工具。用 curl 而非 Python 的 httpx/requests，是为了绕开
Anaconda/conda 自带 OpenSSL 与某些证书链不兼容的报错。

## 依赖

- Python 3.8+(仅标准库)
- `curl`(Windows 10+ 自带 `curl.exe`；macOS/Linux 自带)

## 配置

全部走环境变量，**也支持从 home 目录的 `~/.env` 自动加载**(零依赖)：

| 变量 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `DS_VISION_API_KEY`  | ✅ | (空) | 后端 API Key |
| `DS_VISION_BASE_URL` | ❌ | `https://api.mimo.xiaomi.com/v1` | OpenAI 兼容 base_url(不带 `/chat/completions`) |
| `DS_VISION_MODEL`    | ❌ | `mimo-v2.5` | 视觉模型名 |
| `DS_VISION_TIMEOUT`  | ❌ | `120` | 单次请求超时(秒) |
| `DS_VISION_ENV_FILE` | ❌ | `~/.env` | `.env` 文件路径(覆盖默认位置) |

### 推荐：写 `~/.env`(即 `C:\Users\<你>\.env`)

```dotenv
DS_VISION_API_KEY=你的key
DS_VISION_BASE_URL=https://api.mimo.xiaomi.com/v1
DS_VISION_MODEL=mimo-v2.5
```

server 启动时会自动加载它，**真实环境变量优先**(已在系统/MCP `env` 里设过的不会被 `.env` 覆盖)。
这样注册 MCP 时就不必把 key 写进 `.claude.json`。

> 换后端只需改 `DS_VISION_BASE_URL` / `DS_VISION_MODEL` / `DS_VISION_API_KEY`，
> 任意支持 `image_url` 的 `/chat/completions` 端点都能接。

## 注册到 Claude Code

推荐用一键脚本(自动算路径、去重、自检、列表验证)：

```powershell
powershell -ExecutionPolicy Bypass -File ds_vision_mcp/setup.ps1
# 可选: -Name 自定义注册名   -Python 指定 python 路径
```

或手动：

```bash
claude mcp add ds-vision -- python "D:/dev/tunan.git/ds_vision_mcp/server.py"
```

密钥已放在 `~/.env`(见上一节),无需再往 `.claude.json` 写 `env`。
若仍想在 `.claude.json` 里覆盖,加 `env` 块即可——它优先级高于 `.env`。

验证：

```bash
claude mcp list
# ds-vision: python D:/dev/tunan.git/ds_vision_mcp/server.py - ✓ Connected
```

## 使用

在对话里直接让模型识图，或：

```
分析一下 C:\screenshots\error.png 这张截图
```

模型会调用 `describe_image(image_path, prompt?)`。

## 本地自检(不调真实 API)

```bash
python ds_vision_mcp/selftest.py
```

校验 initialize / tools/list 协议与 base64 编码是否正常。
