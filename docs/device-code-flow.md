# 档位 3 — Device Code Flow（待后端实现）

> 当前 install.sh 走的是档位 1（用户手动复制 API Key）。这份文档列出**升级到档位 3** 需要后端 + CLI 配合做哪些事。落地后 install.sh 只需替换 `# ─── 2. API Key ───` 那一节即可，其他逻辑都不动。

## 用户感受的对比

| 流程 | 档位 1（当前） | 档位 3（目标） |
|------|---------------|----------------|
| 用户操作 | 在 console.dbay.cloud 创建 Key → 手动复制 → 粘回对话框 | 浏览器打开预填 URL → 点"授权" |
| 用户消息次数 | 2（"帮我装" + "Key 是 lk_xxx"） | 1（"帮我装"） |
| 复制粘贴 | 1 次（API Key） | 0 次 |
| 对应业界 | — | `gh auth login`、`stripe login`、`fly auth login` |

## 工作清单

### 1. lakeon-api 加 OAuth 2.0 Device Authorization Grant 接口（RFC 8628）

#### `POST /oauth/device/code`

**请求体**（无需鉴权）：
```json
{ "client_id": "dbay-cli", "scope": "memory knowledge" }
```

**响应**：
```json
{
  "device_code": "GmRhmhcxhwAzkoEqiMEg_DnyEysNkuNhszIySk9eS",
  "user_code": "WDJB-MJHT",
  "verification_uri": "https://console.dbay.cloud/device",
  "verification_uri_complete": "https://console.dbay.cloud/device?code=WDJB-MJHT",
  "expires_in": 1800,
  "interval": 5
}
```

实现要点：
- `device_code`：32+ 字节随机；服务端存 `(device_code, user_code, status, tenant_id?, expires_at)`
- `user_code`：易输入的 8 字符（`A-Z` 去掉易混的 `0/O/1/I`）
- `expires_in`：30 分钟
- `interval`：客户端最小轮询间隔 5 秒

#### `POST /oauth/device/token`

**请求体**：
```json
{ "client_id": "dbay-cli", "device_code": "GmRhmhcxhwAzkoEqi..." }
```

**响应**（按状态分支）：
```json
// pending（用户尚未授权）
HTTP 400 { "error": "authorization_pending" }

// 已批准
HTTP 200 { "access_token": "lk_xxx", "token_type": "ApiKey", "tenant_id": "tnt_..." }

// 用户拒绝
HTTP 400 { "error": "access_denied" }

// device_code 过期
HTTP 400 { "error": "expired_token" }

// 客户端轮询过快
HTTP 400 { "error": "slow_down" }
```

实现要点：
- 状态码故意按 RFC 8628 用 400 + error 字段，便于客户端简单分支
- `access_token` 直接发 dbay 的 long-lived API Key（与 console "Create Key" 同款），落到 `~/.dbay/config.json`

### 2. console 加 `/device` 页面

**未登录**：跳到 `/login?next=/device&code=WDJB-MJHT`，登录或注册后回来。

**已登录**：
```
┌────────────────────────────────────────┐
│ 设备授权                                │
│                                         │
│ 一个设备正在请求访问你的 dbay 账号。    │
│                                         │
│ 应用：DBay CLI (dbay-cli/0.4.x)         │
│ 来源：dbay-cli on eugene-mbp           │
│ 申请权限：记忆 + 知识库读写             │
│                                         │
│ 验证码：  WDJB-MJHT                     │
│ ┌──────┐  ┌────────────────┐           │
│ │ 拒绝 │  │   ✓ 批准授权   │           │
│ └──────┘  └────────────────┘           │
└────────────────────────────────────────┘
```

- 如果 URL 带 `?code=XXX`，预填验证码（pad 一下让用户只需点"批准"）
- 批准后调 `POST /api/v1/oauth/device/approve`，把 `device_code` 状态置为 approved，并签发一个 API Key 关联到这个 device_code 记录
- 显示"已授权，回到终端继续即可"

### 3. dbay-cli 加 `dbay auth device` 子命令

```python
# dbay-cli 新增
dbay auth device                # 启动 device flow，等到换出 token
dbay auth device begin          # 只发起、打印 user_code 后立即退出（两段式）
dbay auth device complete       # 配合 begin 用，轮询直到 token
```

`dbay auth device` 单段实现（伪代码）：

```python
def auth_device():
    # 1. 申请 device code
    r = post("/oauth/device/code", json={"client_id": "dbay-cli"})
    print(f"在浏览器打开：  {r.verification_uri_complete}")
    print(f"输入码：       {r.user_code}")
    print("等待授权...")

    # 2. 轮询 token
    while True:
        time.sleep(r.interval)
        t = post("/oauth/device/token", json={"device_code": r.device_code})
        if t.ok:
            write_config(t.access_token)
            print(f"✓ 已授权 ({t.tenant_id})")
            return
        if t.error == "authorization_pending":
            continue
        if t.error == "slow_down":
            r.interval += 5
            continue
        if t.error in ("expired_token", "access_denied"):
            sys.exit(f"授权失败：{t.error}")
```

### 4. install.sh 升级

把 `# ─── 2. API Key ───` 整段换成：

```bash
if [ -f "$CFG" ] && grep -q api_key "$CFG" 2>/dev/null; then
  ok "已有 ~/.dbay/config.json"
elif [ -n "${DBAY_API_KEY:-}" ]; then
  # 同档位 1
  ...
else
  info "启动浏览器授权..."
  if [ -n "${HERMES_AGENT:-}" ] || ! tty_supports_long_polling; then
    # Hermes 走两段式：避开 600s 超时
    dbay auth device begin
    cat <<'EOF'

授权完成后告诉我"好了"，我会跑：
  dbay auth device complete && bash <(curl ... install.sh)
EOF
    exit 2
  else
    # Claude Code / OpenClaw 单段式
    dbay auth device || fail "授权失败"
  fi
fi
```

`tty_supports_long_polling` 检测当前是否在 Hermes shell（暴露 `HERMES_AGENT=1` 或类似 env）；不在的话假设有 30 分钟以上的前台容忍（Claude Code、OpenClaw、本地终端）。

## 验收

- 完全没用过 dbay 的人，只发"帮我装 dbay"，全程**0 次复制粘贴**
- 老用户重跑 install.sh 不被打扰（已有 config.json 直接跳过）
- Hermes 用户两段式仍然可对话完成

## 不需要做的事

- **不**支持自动注册 —— `/device` 页面登录失败时跳到 `/signup?next=/device?code=...`，让用户走标准注册流程
- **不**做 PKCE / refresh token —— dbay API Key 是长期凭证，无需轮换
- **不**单独加端点鉴权 —— device flow 接口本身无鉴权，靠 `device_code` 不可猜 + 短过期保护
