#!/usr/bin/env bash
# cg-link 安装脚本
# 用法: ./install.sh "<Grok Bot 里那个 Bot 的名字>"
set -euo pipefail

BOT="${1:-}"
if [ -z "$BOT" ]; then
  echo "用法: ./install.sh \"<Bot 名字>\"   名字要和 Grok Bot 应用里显示的完全一致" >&2
  exit 2
fi

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}/cg-link"
BRIDGE="${CG_LINK_BRIDGE:-$HOME/.cg-link/bridge}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "缺少 $1：$2" >&2; exit 1; }; }
need node "安装 Node.js 22 或更新版本"
need npm  "随 Node.js 一起安装"
need curl "系统自带，或用包管理器安装"
need git  "安装 Git"
command -v gh >/dev/null 2>&1 || echo "提示：没装 GitHub CLI（gh）。审 PR、合并要用到它：https://cli.github.com"

major="$(node -p 'process.versions.node.split(".")[0]')"
[ "$major" -ge 22 ] || { echo "Node.js 版本太低（当前 $major），需要 22 或更新" >&2; exit 1; }

# 1. 桥接项目：一个只挂载 Grok Bot 扩展的 BDK 项目
if [ -d "$BRIDGE" ]; then
  echo "桥接项目已存在：${BRIDGE}（保留不动）"
else
  echo "创建桥接项目：$BRIDGE"
  mkdir -p "$BRIDGE/bot/extensions"
  cat >"$BRIDGE/package.json" <<'JSON'
{
  "name": "grokbot",
  "private": true,
  "type": "module",
  "description": "cg-link bridge: lets Claude Code consult a named Grok Bot.",
  "dependencies": {
    "@cursor/bdk": "^0.2.24"
  }
}
JSON
  cat >"$BRIDGE/bot/agent.ts" <<'TS'
import { defineAgent } from "@cursor/bdk";

export default defineAgent({
  // 只要挂载的 Grok Bot 工具，不给别的工具
  tools: [],
});
TS
  bot_json="$(node -e 'process.stdout.write(JSON.stringify(process.argv[1]))' "$BOT")"
  cat >"$BRIDGE/bot/extensions/grokbot.ts" <<TS
import cursorGrokBotAgents from "@cursor/bdk/extensions/cursor-grokbot-agents";

export default cursorGrokBotAgents({
  agents: [$bot_json],
});
TS
  cat >"$BRIDGE/bot/instructions.md" <<'MD'
# cg-link bridge

Consult the Grok Bot agents named in `bot/extensions/grokbot.ts` and report the reply.
MD
  printf 'node_modules\n.agent-serve\nmemory\n.env\n' >"$BRIDGE/.gitignore"
  (cd "$BRIDGE" && npm install --silent --no-fund --no-audit)
fi

# 2. Skill：复制到 Claude Code 的 skills 目录，并填入 Bot 名字
mkdir -p "$SKILL_DIR"
for f in SKILL.md protocol.md; do
  BOT="$BOT" node -e '
    const fs = require("fs");
    const [src, dst] = process.argv.slice(1);
    fs.writeFileSync(dst, fs.readFileSync(src, "utf8").replaceAll("{{BOT}}", process.env.BOT));
  ' "$HERE/skill/$f" "$SKILL_DIR/$f"
done
cp "$HERE/skill/cg.sh" "$SKILL_DIR/cg.sh"
chmod +x "$SKILL_DIR/cg.sh"
echo "Skill 已安装：$SKILL_DIR"

# 3. 登录检查
if "$BRIDGE/node_modules/.bin/bdk" whoami >/dev/null 2>&1; then
  echo "Cursor 已登录"
else
  echo
  echo "还没登录 Cursor。运行下面这条，会打开浏览器授权："
  echo "  $BRIDGE/node_modules/.bin/bdk login"
fi

cat <<MSG

最后两步：
1. 打开 Grok Bot 应用，找到「${BOT}」，把下面这个文件的内容粘进它的指令（Instructions）：
   $SKILL_DIR/protocol.md
2. 测试连通（不会给 Bot 发消息）：
   $SKILL_DIR/cg.sh list

然后在 Claude Code 里说「/cg-link 帮我做 XXX」就可以了。
MSG
