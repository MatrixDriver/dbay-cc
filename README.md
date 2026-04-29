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

## 一键安装

**方式一：让 Agent 自动安装（推荐）**

直接对你的 AI Agent 说：

```
帮我安装这个 skill：https://github.com/MatrixDriver/dbay-cc
```

**方式二：npx skills 安装**

```bash
npx skills add MatrixDriver/dbay-cc
```

**方式三：Claude Code Plugin**

```bash
claude plugin marketplace add https://github.com/MatrixDriver/dbay-cc
claude plugin install dbay@dbay --scope user
```

**方式四：手动**

```bash
git clone https://github.com/MatrixDriver/dbay-cc ~/.claude/skills/dbay
```

## 快速开始

```bash
# 1. 安装 CLI
pip install dbay-cli

# 2. 登录（打开浏览器完成认证）
dbay login

# 3. 创建记忆库
dbay mem create my-mem
dbay mem use my-mem

# 4. 注册 MCP 到 Claude Code
claude mcp add --scope user dbay -- uvx dbay-mcp

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

| 平台 | MCP 配置方式 |
|------|-------------|
| Claude Code | `claude mcp add --scope user dbay -- uvx dbay-mcp` |
| OpenClaw | 编辑 `~/.openclaw/mcp.json`，添加 `dbay` 条目，重启 gateway |
| Hermes Agent | 编辑 `config.yaml`，在 `mcp_servers` 下添加 `dbay` 条目 |

详细配置示例见 [SKILL.md](./SKILL.md) 和 `configs/` 目录。
I](https://pypi.org/project/dbay-mcp/) — MCP Server 包
- [dbay-cli on PyPI](https://pypi.org/project/dbay-cli/) — CLI 工具包
