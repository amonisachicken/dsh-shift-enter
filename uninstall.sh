#!/usr/bin/env bash
# 从 profile 移除 dsh-shift-enter；可选回退 DSH 补丁并重建客户端包。
#
#   ./uninstall.sh
#   ./uninstall.sh --profile web
#   ./uninstall.sh --dsh ~/devel/deepseek-harness --revert-patch
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME="$(node -e 'process.stdout.write(require(process.argv[1]).name)' "$REPO/package.json")"
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
PROFILE="web"
DSH_DIR=""
REVERT="0"
DRY_RUN="0"

PATCH="$REPO/dsh-patch/0001-switchable-composer-send-gesture.patch"
COMMIT_MSG="local: switchable composer send gesture"

usage() {
  cat <<'EOF'
用法：./uninstall.sh [选项]

  --profile <name>  目标 profile，默认 web
  --dsh <path>      回退补丁时需要的 DSH 源码 checkout
  --revert-patch    同时回退 DSH 补丁并重建客户端包
  --dry-run         只打印计划，不改文件
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="${2:?--profile 需要一个名字}"; shift 2 ;;
    --dsh) DSH_DIR="${2:?--dsh 需要一个路径}"; shift 2 ;;
    --revert-patch) REVERT="1"; shift ;;
    --dry-run) DRY_RUN="1"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数：$1" >&2; usage >&2; exit 2 ;;
  esac
done

PROFILE_DIR="$DSH_HOME/profiles/$PROFILE"
[[ -d "$PROFILE_DIR" ]] || { echo "找不到 profile：$PROFILE_DIR" >&2; exit 1; }
[[ -f "$PROFILE_DIR/package.json" ]] || { echo "profile 缺少 package.json：$PROFILE_DIR" >&2; exit 1; }

if [[ "$DRY_RUN" == "1" ]]; then
  echo "（dry run）将从 $PROFILE_DIR 移除 $NAME"
  [[ "$REVERT" == "1" ]] && echo "（dry run）将回退 DSH 补丁并重建（需要 --dsh 指向源码 checkout）"
  exit 0
fi

node - "$PROFILE_DIR/package.json" "$NAME" <<'NODE'
const { readFileSync, writeFileSync } = require('node:fs')
const [file, name] = process.argv.slice(2)
const pkg = JSON.parse(readFileSync(file, 'utf8'))
delete pkg.dependencies?.[name]
if (pkg.dsh?.profile?.bundles) {
  pkg.dsh.profile.bundles = pkg.dsh.profile.bundles.filter(entry => entry !== name)
}
writeFileSync(file, JSON.stringify(pkg, null, 2) + '\n')
console.log('已写入 ' + file)
NODE

if command -v pnpm >/dev/null 2>&1; then
  echo "更新 profile 依赖（pnpm install）…"
  ( cd "$PROFILE_DIR" && pnpm install --silent )
else
  echo "没有 pnpm：请在 $PROFILE_DIR 手动运行 pnpm install" >&2
  exit 1
fi

if [[ "$REVERT" == "1" ]]; then
  if [[ -z "$DSH_DIR" ]]; then
    echo "回退补丁需要 --dsh <DSH 源码 checkout>。" >&2
    exit 1
  fi
  MARKER="$DSH_DIR/packages/client/ui-conversation/src/client/conversation/assembly.ts"
  [[ -f "$MARKER" ]] || { echo "不是 DSH 源码仓库：$DSH_DIR" >&2; exit 1; }
  if grep -q 'setComposerSendGesture' "$MARKER"; then
    if [[ "$(git -C "$DSH_DIR" log -1 --format=%s 2>/dev/null || true)" == "$COMMIT_MSG" ]]; then
      echo "回退补丁提交（git revert HEAD）…"
      git -C "$DSH_DIR" revert --no-edit HEAD
    else
      echo "反向应用补丁（git apply -R）…"
      ( cd "$DSH_DIR" && git apply -R "$PATCH" )
    fi
    if [[ -x "$DSH_DIR/node_modules/.bin/tsc" ]]; then
      echo "重建 @deepseek-ai/dsh-client-ui-conversation …"
      ( cd "$DSH_DIR" \
        && node_modules/.bin/tsc -b packages/client/ui-conversation/tsconfig.client.json \
        && pnpm --filter @deepseek-ai/dsh-client-ui-conversation run bundle )
    else
      echo "未找到 $DSH_DIR/node_modules/.bin/tsc：请稍后手动重建客户端包。" >&2
    fi
  else
    echo "DSH 源码里没有该补丁，跳过。"
  fi
fi

echo
echo "完成。刷新页面（或重启 DSH）即可回到 Enter 发送、Shift+Enter 换行。"
