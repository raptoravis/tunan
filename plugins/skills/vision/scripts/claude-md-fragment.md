## 前端 UI 视觉检查流程（tunan:vision）

检查前端页面布局 / UI 时，**禁止**仅靠阅读代码推断布局问题，必须用截图 + 视觉模型分析实际渲染：

1. 确保 dev server 已启动，获取页面 URL。
2. 截图覆盖全部内容（用 browser-harness / agent-browser / Playwright 或平台截图工具）：打开页面 → 等待加载 → 等约 2s 渲染 → 全页截图 → 滚动到 2-3 个不同位置各再截一张。
3. 每张截图用 `tunan:vision` skill 分析：
   ```bash
   uv run "${CLAUDE_SKILL_DIR}/scripts/vision.py" "shot.png" "分析布局问题：对齐、间距、溢出、留白、截断、空白区域、对比度、响应式"
   ```
   可用 `--provider doubao|qwen|openai` 切换模型；未指定时按 `VISION_PROVIDER` / 首个 key 自动选。
4. 汇总所有截图的分析结果，列出完整、去重的问题清单后再报告。

key 与 provider 配置见 `~/.env`（`BD_API_KEY` / `DASHSCOPE_API_KEY` / `OPENAI_API_KEY` 等，`DOUBAO_API_KEY` 亦可），`vision.py` 每次运行自动加载。
