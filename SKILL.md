---
name: dbay
description: DBay 知识库 + 记忆 MCP，让 AI Agent 拥有跨会话长期记忆和知识检索能力。触发场景：用户要求记住某事、回忆之前的对话、搜索项目知识库、或需要跨会话保持上下文。
metadata:
  version: "1.0.0"
  author: DBay
  homepage: https://dbay.cloud
  repository: https://github.com/MatrixDriver/dbay-cc
---

# DBay — AI Agent 记忆与知识库

DBay 为 AI Agent 提供两大能力：

- **记忆 (Memory)**: 跨会话长期记忆，Agent 可以记住你的偏好、决策、项目上下文
- **知识库 (Knowledge)**: 上传文档后语义检索，Agent 可以搜索你的项目文档、Wiki

## 前置条件

检查 Python 3.10+ 和 pip 是否可用：

```bash
python3 --version && pip --version
```

## 安装步骤

### 第一步：安装 CLI 并登录

```bash
pip install dbay-cli
dbay login
```

`dbay login` 会打开浏览器完成认证，API Key 存在 `~/.dbay/config.json`，不会进入 Agent 配置文件。

### 第二步：创建记忆库

```bash
dbay mem create my-mem
dbay mem use my-mem
```

如需端到端加密记忆库：
```bash
dbay mem create --encrypted my-private-mem
```

### 第三步：注册 MCP 服务器

根据不同平台执行对应命令。

#### Claude Code

```bash
claude mcp add --scope user dbay -- uvx dbay-mcp
```

#### OpenClaw

编辑 `~/.openclaw/mcp.json`（如文件不存在则创建），添加或合并以下内容：

```json
{
  "mcpServers": {
    "dbay": {
      "command": "uvx",
      "args": ["dbay-mcp"]
    }
  }
}
```

然后重启 gateway：`openclaw gateway restart`

#### Hermes Agent

在 Hermes 的 `config.yaml` 中添加：

```yaml
mcp_servers:
  dbay:
    command: "uvx"
    args: ["dbay-mcp"]
    timeout: 60
    connect_timeout: 30
```

重启 hermes gateway 使配置生效。

### 第四步：验证

安装完成后，可用工具包括：

| 工具 | 用途 |
|------|------|
| `memory_recall` | 语义检索记忆 |
| `memory_ingest` | 存储记忆 |
| `memory_list` | 列出记忆 |
| `memory_delete` | 删除记忆 |
| `knowledge_search` | 搜索知识库 |
| `knowledge_list_bases` | 列出知识库 |
| `knowledge_list_documents` | 列出文档 |
| `knowledge_get_chunk` | 获取文档片段 |

### 记忆溯源

每次调用 `memory_ingest` 时，必须传入 `source` 参数标识自己的来源：

| Agent | `source` 值 |
|-------|-------------|
| Claude Code | `claude-code` |
| OpenClaw | `openclaw` |
| Hermes Agent | `hermes-agent` |

示例：
```
memory_ingest(content="用户的偏好是...", memory_type="fact", source="openclaw")
```

这样记忆库中的每条记忆都有源头可查，不会混淆是哪个 Agent 记录的。

## 可选：SRE 诊断 MCP

如果需要日志诊断、租户定位等 SRE 运维能力，可额外安装 `dbay-sre-mcp`：

```bash
pip install dbay-sre-mcp
```

配置环境变量后注册 MCP：

```bash
# 必需环境变量
export LOG_DB_DSN="postgresql://..."
export LAKEON_ADMIN_TOKEN="..."
export LAKEON_API_BASE_URL="https://api.dbay.cloud:8443/api/v1"
```

Claude Code:
```bash
claude mcp add --scope user dbay-sre-mcp -- dbay-sre-mcp
```

OpenClaw 在 `~/.openclaw/mcp.json` 中添加 `dbay-sre-mcp` 条目；Hermes 在 `config.yaml` 中添加对应 `mcp_servers` 条目，env 字段需显式声明上述环境变量。

## 常见坑

### Hermes 的 `memory` 工具 ≠ DBay 记忆

Hermes Agent **内置的 `memory` 工具** 只写入本地 `~/.hermes/` 目录，**不会写入 DBay**。要让信息进入 DBay 长期记忆，必须明确调用 DBay MCP 的 `memory_ingest` 工具或使用 `dbay mem ingest` CLI 命令。

**在 Hermes 中保存到 DBay 的正确方式：**

方式一（推荐 — MCP 工具，通过 uvx dbay-mcp）：
```
memory_ingest(content="...", memory_type="fact|decision|rejection|convention|procedural|episode", source="hermes-agent")
```

方式二（API 直调，当 MCP 未就绪时）：
```python
from dbay_cli.client import DbayClient
client = DbayClient(base_url, api_key)
client.mem_ingest(
    mem_id="mem_xxx",
    content="...",
    role="assistant",
    memory_type="decision",
    source="hermes-agent"
)
```

### `dbay mem ingest` CLI 选项

```
dbay mem ingest "..." [--type TYPE] [--source TAG] [--raw]
```

- `--type`：`fact|decision|rejection|convention|procedural|episode`，默认 `fact`
- `--source`：来源标签（如 `cli`、`claude-code`、`hermes-agent`），默认 `cli`
- `--raw`：把内容当作原始对话，让服务端 LLM 自动抽取（`signal="conversation"`）。**不加**此选项时默认按结构化记忆直接落库（`signal="memory"`），跟 MCP `memory_ingest` 行为一致。

> 历史注：旧版本曾有 `--no-extract` 选项，因为客户端从未实现对应字段且会污染 `signal` 字段，已在 dbay-cli 修复后删除——升级到最新版即可，**不要再用 `--no-extract`**。

### `memory_type` 是必填项

当 `signal='memory'` 时，API 要求 `memory_type` 字段。可选值：`fact`, `decision`, `rejection`, `convention`, `procedural`, `episode`。不传会返回 400 错误。

### 多平台共享同一记忆库

DBay 支持多个 Agent（Hermes / Claude Code / OpenClaw）连接**同一个记忆库**。每条记忆通过 `source` 字段（`hermes-agent` / `claude-code` / `openclaw`）标识来源。三个平台都配好 MCP 后，在一个平台上存储的记忆，其他平台均可 `memory_recall` 搜索到。

## 注意事项

- `dbay-mcp` 读取 `~/.dbay/config.json` 获取 API Key，确保 `dbay login` 已完成
- 端到端加密记忆库的密钥文件在 `~/.dbay/encrypted_bases.json`，密码在 `~/.dbay/secret`
- 换设备时复制 `~/.dbay/` 目录即可迁移
