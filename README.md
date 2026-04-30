# DBay — AI Agent 记忆与知识库

给 AI Agent 装上长期记忆和知识检索能力。支持 **Claude Code / OpenClaw / Hermes Agent**。

## 能力

| 能力 | 说明 |
|------|------|
| 跨会话记忆 | Agent 记住你的偏好、决策、项目上下文，下次对话自动加载 |
| 知识库检索 | 上传 PDF/DOCX/MD 文档，Agent 语义搜索并引用 |
| 端到端加密 | 记忆内容本地加密后上传，服务端不可见明文 |
| 多平台 | 同一套 MCP 在 Claude Code / OpenClaw / Hermes 通用，共享记忆库 |
| 记忆溯源 | 每条记忆自动标注来源（claude-code / openclaw / hermes-agent），可追溯是谁记的 |

## 一键安装（对话式）

**直接把这一行发给你的 AI Agent**（Claude Code / OpenClaw / Hermes 都支持）：

```
帮我跑：bash <(curl -fsSL https://raw.githubusercontent.com/MatrixDriver/dbay-cc/main/install.sh)
```

脚本会自动：装 dbay-cli → 引导你拿 API Key → 创建记忆库 → 注册 MCP 到当前 Agent。

第一次跑会让你去 [console.dbay.cloud](https://console.dbay.cloud) 注册（**免费、不需要邀请码**）→ 复制 API Key → 把 Key 粘回对话。Agent 会带着 Key 重跑：

```
DBAY_API_KEY=lk_xxx bash <(curl -fsSL https://raw.githubusercontent.com/MatrixDriver/dbay-cc/main/install.sh)
```

完成后按提示让 MCP 生效：

| 平台 | 让新 MCP 生效 |
|------|--------------|
| Claude Code | 重启 `claude` 进程 |
| OpenClaw | 自动监听配置文件，无需操作 |
| Hermes Agent | 在对话框输入 `/reload-mcp` |

---

### 其他安装方式

**手动按 SKILL.md 操作**

`pip install dbay-cli` → `dbay login` → `dbay mem create` → 编辑 Agent MCP 配置（详见 [SKILL.md](./SKILL.md)）。

**Claude Code Plugin**

```bash
claude plugin marketplace add https://github.com/MatrixDriver/dbay-cc
claude plugin install dbay@dbay --scope user
```

## 快速开始

```bash
# 1. 安装 CLI
pip install dbay-cli

# 2. 登录（打开浏览器完成认证；headless 环境见 SKILL.md）
dbay login

# 3. 创建记忆库
dbay mem create my-mem
dbay mem use my-mem

# 4. 注册 MCP 到 Claude Code（DBAY_SOURCE 让 dbay 知道是谁写的）
claude mcp add --scope user dbay --env DBAY_SOURCE=claude-code -- uvx dbay-mcp

# 完成！Claude 现在拥有跨会话记忆。
```

## 使用示例

安装后直接对 Agent 说：

- "记住：我们的 API 端口约定是 8443"
- "我之前那个关于数据库迁移的决定是什么？"
- "搜索知识库里关于部署流程的文档"
- "帮我回顾一下上周做的架构决策"

## 端到端加密记忆库

敏感信息不希望服务端看到？创建加密记忆库：

```bash
dbay mem create --encrypted my-private-mem
dbay mem use my-private-mem
```

内容在本地用 AES-256-GCM 加密后才上传，密钥只有你持有。

## 多平台配置

每个 Agent 都通过 `DBAY_SOURCE` 环境变量给写入的记忆打来源标签，溯源不会混。

| 平台 | MCP 配置方式 |
|------|-------------|
| Claude Code | `claude mcp add --scope user dbay --env DBAY_SOURCE=claude-code -- uvx dbay-mcp` |
| OpenClaw | 把 `dbay` 条目（带 `env.DBAY_SOURCE=openclaw`）合并进 `~/.openclaw/openclaw.json` 的 `mcpServers` 块，重启 gateway |
| Hermes Agent | 在 `~/.hermes/config.yaml` 的 `mcp_servers` 下添加 `dbay` 条目（带 `env.DBAY_SOURCE=hermes-agent`） |

详细配置示例见 [SKILL.md](./SKILL.md) 和 `configs/` 目录。

## Links

- [DBay Console](https://console.dbay.cloud) — Web 管理后台
- [dbay-mcp on PyPI](https://pypi.org/project/dbay-mcp/) — MCP Server 包
- [dbay-cli on PyPI](https://pypi.org/project/dbay-cli/) — CLI 工具包
