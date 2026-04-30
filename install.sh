#!/usr/bin/env bash
# DBay 一键安装：CLI + 记忆库 + MCP 注册
# 自动检测并装到：Claude Code / OpenClaw / Hermes Agent
#
# 用法：
#   bash <(curl -fsSL https://raw.githubusercontent.com/MatrixDriver/dbay-cc/main/install.sh)
#
# 可选环境变量：
#   DBAY_API_KEY=lk_xxx              已有 key 时跳过登录提示
#   DBAY_MEM_NAME=my-mem             记忆库名（默认 my-mem）
#   DBAY_API_ENDPOINT=https://...    自定义后端（默认 https://api.dbay.cloud:8443）
#   DBAY_SKIP_AGENTS=hermes,claude   逗号分隔，跳过某些 Agent 的 MCP 注册

set -eu

# ─── 输出 ──────────────────────────────────────────────────────────
if [ -t 1 ]; then
  B='\033[1m'; G='\033[32m'; Y='\033[33m'; R='\033[31m'; N='\033[0m'
else
  B=''; G=''; Y=''; R=''; N=''
fi
ok()    { printf "${G}✓${N} %s\n" "$*"; }
info()  { printf "${B}→${N} %s\n" "$*"; }
warn()  { printf "${Y}⚠${N} %s\n" "$*"; }
fail()  { printf "${R}✗${N} %s\n" "$*" >&2; exit 1; }

ENDPOINT="${DBAY_API_ENDPOINT:-https://api.dbay.cloud:8443}"
MEM_NAME="${DBAY_MEM_NAME:-my-mem}"
SKIP="${DBAY_SKIP_AGENTS:-}"
should_skip() { case ",$SKIP," in *",$1,"*) return 0;; *) return 1;; esac; }

echo ""
printf "${B}DBay 一键安装${N} (CLI + 记忆库 + MCP)\n"
echo ""

# ─── 1. dbay-cli ──────────────────────────────────────────────────
if command -v dbay >/dev/null 2>&1; then
  ok "dbay CLI 已安装：$(dbay --version 2>/dev/null || echo unknown)"
else
  info "安装 dbay-cli..."
  if command -v pipx >/dev/null 2>&1; then
    pipx install dbay-cli >/dev/null || fail "pipx install dbay-cli 失败"
  elif command -v pip >/dev/null 2>&1; then
    pip install --quiet --upgrade dbay-cli || fail "pip install dbay-cli 失败"
  elif command -v pip3 >/dev/null 2>&1; then
    pip3 install --quiet --upgrade dbay-cli || fail "pip3 install dbay-cli 失败"
  else
    fail "需要 pip 或 pipx。请先装 Python 3.10+ 后重试。"
  fi
  ok "dbay-cli 装好"
fi

# Hermes 配置 patch 要 PyYAML
if ! python3 -c "import yaml" >/dev/null 2>&1; then
  if command -v pip >/dev/null 2>&1; then
    pip install --quiet pyyaml >/dev/null 2>&1 || true
  elif command -v pip3 >/dev/null 2>&1; then
    pip3 install --quiet pyyaml >/dev/null 2>&1 || true
  fi
fi

# ─── 2. API Key ───────────────────────────────────────────────────
CFG="$HOME/.dbay/config.json"
if [ -f "$CFG" ] && grep -q api_key "$CFG" 2>/dev/null; then
  ok "已有 ~/.dbay/config.json，跳过登录"
elif [ -n "${DBAY_API_KEY:-}" ]; then
  mkdir -p "$HOME/.dbay"
  printf '{ "endpoint": "%s", "api_key": "%s" }\n' "$ENDPOINT" "$DBAY_API_KEY" > "$CFG"
  chmod 600 "$CFG"
  ok "用 \$DBAY_API_KEY 写入 $CFG"
else
  cat <<EOF

──────── 需要 DBay API Key ────────

注册 / 登录 DBay 后拿一个 API Key（免费、无邀请码）：

  1. 浏览器打开：  ${B}https://console.dbay.cloud${N}
  2. 注册或登录
  3. 进入 "API Keys" → "Create"
  4. 复制 Key（形如 lk_xxx）

拿到 Key 后，告诉 Agent："${B}我的 API Key 是 lk_xxx${N}"。
Agent 会执行：

  ${B}DBAY_API_KEY=lk_xxx bash <(curl -fsSL https://raw.githubusercontent.com/MatrixDriver/dbay-cc/main/install.sh)${N}

────────────────────────────────────

EOF
  exit 2
fi

# ─── 3. 记忆库 ────────────────────────────────────────────────────
info "准备记忆库 '$MEM_NAME'..."
if dbay mem create "$MEM_NAME" >/dev/null 2>&1; then
  ok "已创建记忆库 '$MEM_NAME'"
elif dbay mem list 2>/dev/null | grep -q "$MEM_NAME"; then
  ok "记忆库 '$MEM_NAME' 已存在"
else
  fail "创建/查询记忆库失败。请确认 API Key 有效：cat ~/.dbay/config.json"
fi
dbay mem use "$MEM_NAME" >/dev/null 2>&1 || true

# ─── 4. 注册 MCP ──────────────────────────────────────────────────
RELOAD_HINTS=()
DETECTED=0

# Claude Code
if ! should_skip claude && command -v claude >/dev/null 2>&1; then
  DETECTED=$((DETECTED+1))
  info "Claude Code 检测到，注册 dbay MCP..."
  claude mcp remove dbay --scope user >/dev/null 2>&1 || true
  if claude mcp add --scope user dbay --env "DBAY_SOURCE=claude-code" -- uvx dbay-mcp >/dev/null 2>&1; then
    ok "Claude Code: 已注册"
    RELOAD_HINTS+=("Claude Code：重启 claude 进程让新 MCP 生效")
  else
    warn "Claude Code 注册失败，手动跑：claude mcp add --scope user dbay --env DBAY_SOURCE=claude-code -- uvx dbay-mcp"
  fi
fi

# OpenClaw
if ! should_skip openclaw && command -v openclaw >/dev/null 2>&1; then
  DETECTED=$((DETECTED+1))
  info "OpenClaw 检测到，注册 dbay MCP..."
  if openclaw mcp set dbay '{"command":"uvx","args":["dbay-mcp"],"env":{"DBAY_SOURCE":"openclaw"}}' >/dev/null 2>&1; then
    ok "OpenClaw: 已注册"
    RELOAD_HINTS+=("OpenClaw：runtime 自动监听配置文件，无需重启")
  else
    warn "OpenClaw 注册失败，手动跑：openclaw mcp set dbay '{\"command\":\"uvx\",\"args\":[\"dbay-mcp\"],\"env\":{\"DBAY_SOURCE\":\"openclaw\"}}'"
  fi
fi

# Hermes Agent
if ! should_skip hermes && [ -f "$HOME/.hermes/config.yaml" ]; then
  DETECTED=$((DETECTED+1))
  info "Hermes 检测到，合并 dbay 条目到 ~/.hermes/config.yaml..."
  if python3 - <<'PYEOF' >/dev/null 2>&1
import sys, pathlib
try:
    import yaml
except ImportError:
    sys.exit(2)
p = pathlib.Path.home() / ".hermes" / "config.yaml"
data = yaml.safe_load(p.read_text()) if p.stat().st_size > 0 else {}
data = data or {}
servers = data.get("mcp_servers") or {}
servers["dbay"] = {
    "command": "uvx",
    "args": ["dbay-mcp"],
    "env": {"DBAY_SOURCE": "hermes-agent"},
    "timeout": 60,
    "connect_timeout": 30,
}
data["mcp_servers"] = servers
p.write_text(yaml.safe_dump(data, allow_unicode=True, sort_keys=False))
PYEOF
  then
    ok "Hermes: 已合并条目"
    RELOAD_HINTS+=("Hermes：在对话框输入 ${B}/reload-mcp${N} 让新工具生效")
  else
    warn "Hermes 合并失败（可能缺 PyYAML）。手动 pip install pyyaml 后重试，或手动编辑 ~/.hermes/config.yaml"
  fi
fi

if [ "$DETECTED" -eq 0 ]; then
  warn "未检测到 Claude Code / OpenClaw / Hermes 中的任何一个"
  warn "如果你的 Agent 不在 PATH 里，请按 SKILL.md 手动注册 MCP："
  warn "  https://github.com/MatrixDriver/dbay-cc/blob/main/SKILL.md"
fi

# ─── 5. 收尾 ──────────────────────────────────────────────────────
echo ""
ok "${B}DBay 安装完成！${N}"
if [ "${#RELOAD_HINTS[@]}" -gt 0 ]; then
  echo ""
  echo "下一步："
  for h in "${RELOAD_HINTS[@]}"; do
    printf "  • %b\n" "$h"
  done
fi
echo ""
echo "测试：对 Agent 说 \"请记住：我们 API 端口约定是 8443\""
echo "Console: https://console.dbay.cloud"
echo ""
