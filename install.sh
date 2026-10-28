#!/usr/bin/env bash
# cdwin 安装 / 卸载脚本
#   用法：./install.sh            # 安装到 ~/.local/share/cdwin 并挂到 ~/.bashrc
#         ./install.sh --uninstall
#         curl -fsSL https://raw.githubusercontent.com/SouthskyVela/cdwin/main/install.sh | bash
set -euo pipefail

REPO="SouthskyVela/cdwin"
BASE_URL="${CDWIN_BASE_URL:-https://raw.githubusercontent.com/$REPO/main}"
DEST_DIR="${CDWIN_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/cdwin}"
RC="${CDWIN_RC:-$HOME/.bashrc}"
MARK_START="# >>> cdwin >>>"
MARK_END="# <<< cdwin <<<"
DO_UNINSTALL=0

usage() {
    cat <<'EOF'
用法: install.sh [选项]
  --dir <路径>    安装目录（默认 ${XDG_DATA_HOME:-~/.local/share}/cdwin）
  --rc <文件>     要修改的启动文件（默认 ~/.bashrc）
  --uninstall     卸载（删除标记块与安装目录）
  -h, --help      显示帮助
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dir) DEST_DIR="$2"; shift 2 ;;
        --rc)  RC="$2"; shift 2 ;;
        --uninstall) DO_UNINSTALL=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "未知参数: $1" >&2; usage; exit 1 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"

say() { printf '%s\n' "$*"; }

remove_block() {
    [ -f "$RC" ] || return 0
    grep -qF "$MARK_START" "$RC" || return 0
    cp -a "$RC" "$RC.cdwin.bak"
    awk -v s="$MARK_START" -v e="$MARK_END" '
        $0 == s { skip = 1; next }
        $0 == e { skip = 0; next }
        !skip
    ' "$RC" > "$RC.cdwin.tmp"
    mv "$RC.cdwin.tmp" "$RC"
    say "已从 $RC 移除 cdwin 标记块（备份：$RC.cdwin.bak）"
}

if [ "$DO_UNINSTALL" -eq 1 ]; then
    remove_block
    if [ -d "$DEST_DIR" ]; then
        rm -rf "$DEST_DIR"
        say "已删除 $DEST_DIR"
    fi
    say "卸载完成，重开终端或执行 source \"$RC\" 生效。"
    exit 0
fi

# 1. 取 cdwin.sh：仓库内直接用本地副本，curl 方式则下载
mkdir -p "$DEST_DIR"
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/cdwin.sh" ]; then
    cp "$SCRIPT_DIR/cdwin.sh" "$DEST_DIR/cdwin.sh"
    say "已复制 $SCRIPT_DIR/cdwin.sh → $DEST_DIR/cdwin.sh"
else
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$BASE_URL/cdwin.sh" -o "$DEST_DIR/cdwin.sh"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$DEST_DIR/cdwin.sh" "$BASE_URL/cdwin.sh"
    else
        echo "需要 curl 或 wget 下载 cdwin.sh" >&2
        exit 1
    fi
    say "已下载 cdwin.sh → $DEST_DIR/cdwin.sh"
fi
chmod 644 "$DEST_DIR/cdwin.sh"

# 2. 语法自检
if ! bash -n "$DEST_DIR/cdwin.sh"; then
    echo "cdwin.sh 语法检查失败，已中止" >&2
    exit 1
fi

# 3. 写入启动文件标记块（先清旧的，保证可重复安装/升级）
remove_block
[ -f "$RC" ] || { : > "$RC"; }
{
    printf '\n%s\n' "$MARK_START"
    printf '# https://github.com/%s\n' "$REPO"
    printf 'if [ -f "%s" ]; then\n    . "%s"\nfi\n' "$DEST_DIR/cdwin.sh" "$DEST_DIR/cdwin.sh"
    printf '%s\n' "$MARK_END"
} >> "$RC"

say ""
say "安装完成："
say "  脚本    $DEST_DIR/cdwin.sh"
say "  启动项  $RC（标记块 $MARK_START）"
say ""
say "现在执行  source \"$RC\"  或重开终端，然后试试："
say "  cdwin 'C:\\Users\\你的用户名\\Desktop'"
say "  cd -win 'D:\\some\\dir'"
say "  cdwin -h"
