# cg-link

让 Claude Code 当技术负责人，通过 Grok Bot 调度 Cursor cloud agent 干活。

```
你 ──需求──▶ Claude Code ──任务单──▶ Grok Bot ──派活──▶ Cursor cloud agent ×N
   ◀─汇报──              ◀──PR 就绪──           ◀──开 PR──
```

| 角色 | 负责 |
|---|---|
| 你 | 提需求、拍板（部署、花钱、对外发布、设计稿） |
| Claude Code | 理解需求、读代码、拆任务、写任务单、审 PR、合并、汇报 |
| Grok Bot | 按任务单派 cloud agent、盯进度、转达返工、做 PR 基本检查 |
| Cursor cloud agent | 写代码、在自己的机器上跑测试、贴证据、开 PR |

Claude Code 不改业务代码，只读代码和审代码。写代码、跑测试的活都在云端并行跑，可以一次开好几个 cloud agent。

## 三步搭好

开始前确认：Cursor 账号能用 Grok Bot 和 cloud agent，并且 Cursor 里已经连好 GitHub。本机要有 Node.js 22+、Git，以及登录好的 [GitHub CLI](https://cli.github.com)。

**1. 在 Grok Bot 里建一个专用 Bot**

打开 Grok Bot 应用，新建一个 Bot，名字随你起。把 [`skill/protocol.md`](skill/protocol.md) 的全文粘进它的指令。这个 Bot 只用来接 Claude Code 的活。

**2. 让 Claude Code 安装**

把这段发给 Claude Code（`<Bot 名>` 换成第 1 步的名字，要完全一致）：

```
帮我安装 cg-link：https://github.com/lawrencewzen/cg-link
克隆下来，运行 ./install.sh "<Bot 名>"。
```

**3. 登录 Cursor**

```
! ~/.cg-link/bridge/node_modules/.bin/bdk login
```

浏览器里点授权。

搭完后可以这样测连通（不会给 Bot 发消息）：

```bash
~/.claude/skills/cg-link/cg.sh list
```

### install.sh 做了什么

1. 在 `~/.cg-link/bridge` 建一个桥接项目：最小的 BDK（`@cursor/bdk`）项目，只挂载官方的 Grok Bot 扩展，`bdk` 装在项目里，不动全局。
2. 把 skill 装到 `~/.claude/skills/cg-link`，填好 Bot 名字。
3. 检查有没有登录 Cursor。

## 使用

在 Claude Code 里：

```
/cg-link 给设置页加一个暗色模式开关
```

之后 Claude Code 会：

1. 跟你确认需求和验收标准；
2. 在 `~/.cache/claude-review/` 克隆仓库读代码（只读，不碰你的工作副本）；
3. 拆成能并行的子任务，每个写一份任务单发给 Bot；
4. 定时问进度；PR 来了逐个审，不合格写返工意见打回去；
5. 都通过后合并，跟你汇报。

进度记在 `~/.claude/cg-link-tasks.md`，换个会话也能接上。

## 文件

```
skill/
├── SKILL.md      Claude Code 的工作流程：分工、任务单模板、审 PR、合并
├── protocol.md   粘给 Grok Bot 的调度协议
└── cg.sh         通道脚本：ask / check / interrupt / list
install.sh        安装脚本
```

`cg.sh` 的四个工具：

| 工具 | 输入 | 说明 |
|---|---|---|
| ask | `{"agent":"<Bot 名>","message":"...","wait_seconds":120}` | 发一条消息，最多等 600 秒 |
| check | `{"agent":"<Bot 名>","wait_seconds":120}` | 取上次之后的新回复 |
| interrupt | `{"agent":"<Bot 名>"}` | 停掉 Bot 当前这一轮，对话保留 |
| list | `{}` | 列出配置的和联系过的 Bot |

## 环境变量

| 变量 | 默认 | 说明 |
|---|---|---|
| `CG_LINK_BRIDGE` | `~/.cg-link/bridge` | 桥接项目位置 |
| `CG_LINK_PORT` | `4123` | 本地 `bdk serve` 端口 |
| `CG_LINK_LOG` | `~/.cache/cg-link-serve.log` | serve 日志 |
| `CLAUDE_SKILLS_DIR` | `~/.claude/skills` | 安装时 skill 放哪 |

## 常见问题

- **`bdk serve 启动失败`**：看 `~/.cache/cg-link-serve.log`。多半是没登录，运行 `bdk login`。
- **ask 返回 Bot 忙**：Bot 同一时间只处理一条消息。先 `check` 拿回复，或者 `interrupt` 停掉。
- **结果里出现 `created: true`**：Bot 名字和 Grok Bot 应用里的不一致，Grok Bot 新建了一个空 Bot。改 `~/.cg-link/bridge/bot/extensions/grokbot.ts` 里的名字，再 `pkill -f "serve --dir . --port 4123"`。
- **加更多 Bot**：同样改 `grokbot.ts` 的 `agents` 数组。

## 卸载

```bash
pkill -f "serve --dir . --port 4123"
rm -rf ~/.claude/skills/cg-link ~/.cg-link
```

## License

MIT
