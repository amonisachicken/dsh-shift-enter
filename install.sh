#!/usr/bin/env bash
# 安装 dsh-shift-enter：给 DSH 源码打「可切换发送手势」补丁（并重建客户端包），
# 再把本仓库作为 bundle 装进一个 DSH profile。
#
#   ./install.sh --dsh ~/devel/deepseek-harness
#   ./install.sh --dsh ~/devel/deepseek-harness --profile web
#   ./install.sh --dsh ~/devel/deepseek-harness --no-build --dry-run
#   ./install.sh --dsh ~/devel/deepseek-harness --copy
#
# 找不到 DSH 源码时只安装插件并提示：没有补丁，键位不会改变。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME="$(node -e 'process.stdout.write(require(process.argv[1]).name)' "$REPO/package.json")"
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
PROFILE="web"
MODE="link"
DRY_RUN="0"
BUILD="1"
COMMIT="1"
REBUILD="0"
DSH_DIR=""

PATCH="$REPO/dsh-patch/0001-switchable-composer-send-gesture.patch"
COMMIT_MSG="local: switchable composer send gesture"

usage() {
  cat <<'EOF'
用法：./install.sh [选项]

  --dsh <path>     DSH 源码 checkout（省略时自动探测 $DSH_CHECKOUT、$DSH_INSTALL_DIR 上级、~/devel/deepseek-harness）
  --profile <name> 目标 profile，默认 web
  --no-build       只打补丁，不重建客户端包
  --no-commit      打补丁但不提交，改动留在工作区
  --rebuild        已有补丁时也重建客户端包
  --copy           复制到 $DSH_HOME/plugins/<name> 再链接
  --dry-run        只打印计划，不改文件
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="${2:?--profile 需要一个名字}"; shift 2 ;;
    --dsh) DSH_DIR="${2:?--dsh 需要一个路径}"; shift 2 ;;
    --copy) MODE="copy"; shift ;;
    --no-build) BUILD="0"; shift ;;
    --no-commit) COMMIT="0"; shift ;;
    --rebuild) REBUILD="1"; shift ;;
    --dry-run) DRY_RUN="1"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数：$1" >&2; usage >&2; exit 2 ;;
  esac
done

# 没给 --dsh 时按常见位置猜一个 DSH 源码 checkout。
detect_dsh() {
  local candidate
  for candidate in \
    "${DSH_CHECKOUT:-}" \
    "${DSH_INSTALL_DIR:+${DSH_INSTALL_DIR%/apps/cli}}" \
    "$HOME/devel/deepseek-harness" \
    "$HOME/dev/deepseek-harness"; do
    [[ -n "$candidate" ]] || continue
    if [[ -f "$candidate/packages/client/ui-conversation/src/client/input/editor/keymap.ts" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

if [[ -z "$DSH_DIR" ]]; then
  if DSH_DIR="$(detect_dsh)"; then :; else DSH_DIR=""; fi
fi

CORE=0
if [[ -n "$DSH_DIR" ]]; then
  if [[ ! -f "$DSH_DIR/packages/client/ui-conversation/src/client/input/editor/keymap.ts" ]]; then
    echo "不是 DSH 源码仓库：$DSH_DIR" >&2
    exit 1
  fi
  CORE=1
fi

PROFILE_DIR="$DSH_HOME/profiles/$PROFILE"

echo "插件：  $NAME"
echo "profile：$PROFILE_DIR"
if [[ "$CORE" == "1" ]]; then
  echo "DSH：   $DSH_DIR"
else
  echo "DSH：   （未找到源码 checkout）"
fi

if [[ "$DRY_RUN" == "1" ]]; then
  echo
  echo "（dry run：只打印计划，不改任何文件）"
  if [[ "$CORE" == "1" ]]; then
    if grep -q 'setComposerSendGesture' "$DSH_DIR/packages/client/ui-conversation/src/client/conversation/assembly.ts"; then
      echo "  · DSH 已有可切换发送手势的补丁，跳过"
      [[ "$REBUILD" == "1" && "$BUILD" == "1" ]] && echo "  · 将重建 @deepseek-ai/dsh-client-ui-conversation 客户端包（--rebuild）"
    else
      echo "  · 将应用 $PATCH 并提交（可用 --no-commit 关闭）"
      [[ "$BUILD" == "1" ]] && echo "  · 将重建 @deepseek-ai/dsh-client-ui-conversation 客户端包"
    fi
  else
    echo "  · 找不到 DSH 源码：跳过补丁与重建（键位不会改变）"
  fi
  echo "  · 将把 $NAME 写入 profile 依赖与 dsh.profile.bundles，然后 pnpm install"
  exit 0
fi

build_core() {
  local dir="$1"
  command -v pnpm >/dev/null 2>&1 || { echo "需要 pnpm 才能重建客户端包。" >&2; exit 1; }
  echo "重建 @deepseek-ai/dsh-client-ui-conversation …"
  (
    cd "$dir"
    if [[ -x node_modules/.bin/tsc ]]; then
      node_modules/.bin/tsc -b packages/client/ui-conversation/tsconfig.client.json
    else
      npx --no-install tsc -b packages/client/ui-conversation/tsconfig.client.json
    fi
    pnpm --filter @deepseek-ai/dsh-client-ui-conversation run bundle
  ) || { echo "重建失败：请确认 checkout 已 pnpm install。" >&2; exit 1; }
}

if [[ "$CORE" == "1" ]]; then
  MARKER="$DSH_DIR/packages/client/ui-conversation/src/client/conversation/assembly.ts"
  if grep -q 'setComposerSendGesture' "$MARKER"; then
    echo "DSH 已包含可切换发送手势的补丁，跳过（如需重建客户端包，加 --rebuild）。"
    if [[ "$REBUILD" == "1" && "$BUILD" == "1" ]]; then
      build_core "$DSH_DIR"
    fi
  else
    [[ -f "$PATCH" ]] || { echo "缺少补丁文件：$PATCH" >&2; exit 1; }
    echo "给 DSH 打补丁：$DSH_DIR"
    if ( cd "$DSH_DIR" && git apply --check "$PATCH" ); then
      ( cd "$DSH_DIR" && git apply "$PATCH" )
    else
      echo "补丁与当前源码不完全匹配，尝试三方合并（git apply -3）…"
      ( cd "$DSH_DIR" && git apply -3 "$PATCH" ) \
        || { echo "补丁应用失败：DSH 源码版本可能已变化，见 dsh-patch/README.md。" >&2; exit 1; }
    fi
    if [[ "$COMMIT" == "1" ]]; then
      # 只提交补丁涉及的文件；跳过 checkout 的 pre-commit 钩子（补丁已在本仓库验证过，
      # 新机器上钩子依赖未必就绪）。
      PATCH_FILES=()
      while IFS= read -r file; do PATCH_FILES+=("$file"); done \
        < <(sed -n 's|^diff --git a/\(.*\) b/.*|\1|p' "$PATCH")
      if ( cd "$DSH_DIR" && git add -A -- "${PATCH_FILES[@]}" \
        && git commit --no-verify -m "$COMMIT_MSG" -- "${PATCH_FILES[@]}" >/dev/null ); then
        echo "已提交：$COMMIT_MSG"
      else
        echo "提交失败（可忽略）：补丁仍在工作区，建议稍后手动提交。"
      fi
    fi
    if [[ "$BUILD" == "1" ]]; then
      build_core "$DSH_DIR"
    else
      echo "已跳过重建（--no-build）：请稍后手动重建，否则键位不会改变。"
    fi
  fi
else
  echo
  echo "!! 没有找到 DSH 源码 checkout，只安装插件。"
  echo "!! 没有 dsh-patch 补丁时，本插件保持空操作，键位不会改变。"
  echo "!! 需要按键位生效：用 --dsh <checkout> 重新运行，或参考 dsh-patch/README.md。"
fi

if [[ ! -d "$PROFILE_DIR" ]]; then
  echo "找不到 profile：$PROFILE_DIR" >&2
  echo "现有 profile：" >&2
  ls -1 "$DSH_HOME/profiles" >&2 || true
  exit 1
fi
[[ -f "$PROFILE_DIR/package.json" ]] || { echo "profile 缺少 package.json：$PROFILE_DIR" >&2; exit 1; }

TARGET="$REPO"
if [[ "$MODE" == "copy" ]]; then
  TARGET="$DSH_HOME/plugins/$NAME"
  echo "复制到 $TARGET"
  rm -rf "$TARGET"
  mkdir -p "$TARGET"
  cp -R "$REPO/." "$TARGET/"
  rm -rf "$TARGET/.git" "$TARGET/node_modules"
fi

SPEC="link:$TARGET"
echo "依赖：  $NAME → $SPEC"

node - "$PROFILE_DIR/package.json" "$NAME" "$SPEC" <<'NODE'
const { readFileSync, writeFileSync } = require('node:fs')
const [file, name, spec] = process.argv.slice(2)
const pkg = JSON.parse(readFileSync(file, 'utf8'))
pkg.dependencies ??= {}
// 清掉本插件早期的本地名（安装过工作区版本时留下），避免双份 bundle。
for (const [key, value] of Object.entries(pkg.dependencies)) {
  if (key === '@local/composer-send-key'
    || (typeof value === 'string' && value.endsWith('/composer-send-key'))) {
    delete pkg.dependencies[key]
  }
}
pkg.dependencies[name] = spec
pkg.dsh ??= {}
pkg.dsh.profile ??= {}
// 保留框架 bundle 与真实依赖，丢掉旧名字的残留。
pkg.dsh.profile.bundles = (pkg.dsh.profile.bundles ?? []).filter(
  (entry) => entry.startsWith('@deepseek-ai/') || Object.prototype.hasOwnProperty.call(pkg.dependencies, entry),
)
if (!pkg.dsh.profile.bundles.includes(name)) pkg.dsh.profile.bundles.push(name)
writeFileSync(file, JSON.stringify(pkg, null, 2) + '\n')
console.log('已写入 ' + file)
NODE

if command -v pnpm >/dev/null 2>&1; then
  echo "安装依赖（pnpm install）…"
  ( cd "$PROFILE_DIR" && pnpm install --silent )
else
  echo "没有 pnpm：请在 $PROFILE_DIR 手动运行 pnpm install" >&2
  exit 1
fi

echo
echo "完成。下一步："
echo "  1) 重启 DSH（例如重新运行 dsh web），或直接刷新页面"
echo "  2) 按 Cmd/Ctrl+/ 打开快捷键总览，确认“发送消息”显示 Shift+Enter"
echo "  3) 若键位没变：确认 profile 里 $NAME 已启用，且 DSH 是打过补丁的源码 checkout"
