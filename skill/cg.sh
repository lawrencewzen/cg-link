#!/usr/bin/env bash
# cg-link 通道：Claude Code -> 本地 bdk serve -> Grok Bot
# 用法: cg.sh <ask|check|interrupt|list> ['<json>']
set -euo pipefail

BRIDGE="${CG_LINK_BRIDGE:-$HOME/.cg-link/bridge}"
PORT="${CG_LINK_PORT:-4123}"
BASE="http://127.0.0.1:$PORT"
LOG="${CG_LINK_LOG:-$HOME/.cache/cg-link-serve.log}"

tool="${1:?需要工具名: ask|check|interrupt|list}"
input="${2:-}"
[ -n "$input" ] || input='{}'

case "$tool" in
  ask|check|interrupt|list) ;;
  *) echo "未知工具: $tool（只能是 ask|check|interrupt|list）" >&2; exit 2 ;;
esac

if [ ! -d "$BRIDGE" ]; then
  echo "找不到桥接项目: $BRIDGE。先运行 install.sh，或设置 CG_LINK_BRIDGE。" >&2
  exit 1
fi

# 优先用桥接项目自带的 bdk，避免依赖全局安装
BDK="$BRIDGE/node_modules/.bin/bdk"
[ -x "$BDK" ] || BDK="$(command -v bdk || true)"
if [ -z "$BDK" ]; then
  echo "找不到 bdk。在 $BRIDGE 里运行 npm install。" >&2
  exit 1
fi

# serve 按目录名挂载项目：http://127.0.0.1:<端口>/<目录名>
SLUG="$(basename "$BRIDGE")"

# serve 常驻，check 才能接上之前 ask 的已读位置
if ! curl -s -o /dev/null --max-time 2 "$BASE/"; then
  mkdir -p "$(dirname "$LOG")"
  (cd "$BRIDGE" && nohup "$BDK" serve --dir . --port "$PORT" >"$LOG" 2>&1 &)
  for _ in $(seq 1 40); do
    curl -s -o /dev/null --max-time 1 "$BASE/" && break
    sleep 0.5
  done
  curl -s -o /dev/null --max-time 2 "$BASE/" || { echo "bdk serve 启动失败，见 $LOG" >&2; exit 1; }
fi

"$BDK" call "grokbot__$tool" --url "$BASE/$SLUG" --input "$input" 2>/dev/null
