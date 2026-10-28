#!/usr/bin/env bash
# ============================================================================
# cdwin —— 在 WSL 里用 Windows 路径直接跳转
#
#   cdwin 'C:\Users\me\Desktop'      # 反斜杠原样粘贴（建议加引号）
#   cdwin C:/Users/me                # 正斜杠同样可以
#   cd -win 'D:\data'                # 走 cd 的 -win 开关
#   cdwin                            # 不带参数 → Windows 用户目录
#   winpath [路径]                    # 打印对应的 Windows 路径（默认当前目录）
#   winopen [路径]                    # 在资源管理器里打开（默认当前目录）
#   cdwin -h                         # 帮助
#
# 用法：在 ~/.bashrc 中 source 本文件，或运行项目里的 install.sh。
# 项目主页：https://github.com/SouthskyVela/cdwin
# 许可：MIT
# ============================================================================

CDWIN_VERSION="1.0.0"

# 允许用户覆盖默认落点（默认 C:\Users\<你>）；值可以是 Windows 或 Linux 路径
: "${CDWIN_WINHOME:=}"

# Windows 用户目录 → WSL 路径。优先问 Windows（互操作正常时最准），
# 互操作不可用时退化为扫 /mnt/c/Users/*/NTUSER.DAT 挑最近使用的目录。
_cdwin_winhome() {
    if [ -n "${_CDWIN_WINHOME:-}" ]; then printf '%s' "$_CDWIN_WINHOME"; return 0; fi

    if [ -n "$CDWIN_WINHOME" ]; then
        _CDWIN_WINHOME="$(_cdwin_unix "$CDWIN_WINHOME" 2>/dev/null)"
        [ -n "$_CDWIN_WINHOME" ] && { printf '%s' "$_CDWIN_WINHOME"; return 0; }
    fi

    local h=""
    # 1) 互操作正常：直接问 %USERPROFILE%
    if command -v cmd.exe >/dev/null 2>&1; then
        h="$(timeout 3 cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null \
             | tr -d '\r' | grep -E '^[A-Za-z]:[\\/]' | tail -n1)"
        [ -n "$h" ] && _CDWIN_WINHOME="$(wslpath -u "$h" 2>/dev/null)"
    fi
    # 2) 兜底：按 NTUSER.DAT 修改时间挑最近使用的真实用户目录
    if [ -z "${_CDWIN_WINHOME:-}" ]; then
        local d t best="" best_t=0
        for d in /mnt/c/Users/*; do
            [ -f "$d/NTUSER.DAT" ] || continue
            case "${d##*/}" in
                Public|Default|"Default User"|defaultuser0|"All Users") continue ;;
            esac
            t="$(stat -c %Y "$d/NTUSER.DAT" 2>/dev/null || echo 0)"
            if [ "$t" -gt "$best_t" ]; then best_t="$t"; best="$d"; fi
        done
        [ -n "$best" ] && _CDWIN_WINHOME="$best"
    fi
    # 3) 再退一步
    if [ -z "${_CDWIN_WINHOME:-}" ] && [ -d /mnt/c/Users/Public ]; then
        _CDWIN_WINHOME=/mnt/c/Users/Public
    fi

    printf '%s' "${_CDWIN_WINHOME:-}"
}

# Windows 路径 → WSL 路径；已经是 Linux 路径则原样返回
_cdwin_unix() {
    local p="$1"
    [ -z "$p" ] && return 1
    case "$p" in
        /*|'~'*|'.'|'..') printf '%s\n' "$p"; return 0 ;;
    esac

    local q="${p//\\//}"          # 反斜杠统一成正斜杠

    # 不是 Windows 形态（盘符或 UNC）就原样返回，交给 cd 处理，支持相对路径
    case "$q" in
        [A-Za-z]:*|//*) ;;
        *) printf '%s\n' "$q"; return 0 ;;
    esac

    local u
    if command -v wslpath >/dev/null 2>&1; then
        u="$(wslpath -u "$q" 2>/dev/null)"
        [ -n "$u" ] && { printf '%s\n' "$u"; return 0; }
    fi

    # 兜底：自己按盘符转换（wslpath 不在或失败时）
    case "$q" in
        [A-Za-z]:*)
            local d
            d="$(printf '%s' "${q:0:1}" | tr 'A-Z' 'a-z')"
            printf '/mnt/%s%s\n' "$d" "${q:2}"
            return 0 ;;
    esac
    return 1
}

cdwin() {
    local raw="$*" dest
    case "$raw" in
        -h|--help|help)
            cat <<'EOF'
cdwin —— 用 Windows 路径直接跳转

  cdwin 'C:\Users\me\Desktop'   反斜杠路径（建议加引号）
  cdwin C:/Users/me             正斜杠路径
  cdwin                         回到 Windows 用户目录
  cd -win <路径>                等价的 cd 写法
  winpath [路径]                打印对应的 Windows 路径（默认当前目录）
  winopen [路径]                用资源管理器打开（默认当前目录）
  cdwin -v                      显示版本

环境变量：
  CDWIN_WINHOME                 覆盖“无参数时的默认目录”
EOF
            return 0 ;;
        -v|--version)
            echo "cdwin $CDWIN_VERSION"; return 0 ;;
    esac

    # 盘符后紧跟非分隔符 → 反斜杠已被 bash 吃掉（未加引号粘贴的典型症状）
    case "$raw" in
        [A-Za-z]:[!/\\]*)
            echo "cdwin: 路径里的反斜杠被 bash 当转义符吃掉了：'$raw'" >&2
            echo "       请加引号：cdwin 'C:\\Users\\me\\Desktop'，或把 \\ 写成 /。" >&2
            return 2 ;;
    esac

    if [ -z "$raw" ]; then
        _cdwin_winhome >/dev/null          # 触发缓存（在当前 shell 里，不走子 shell）
        dest="${_CDWIN_WINHOME:-}"
        [ -n "$dest" ] || { echo "cdwin: 取不到 Windows 用户目录" >&2; return 2; }
    else
        dest="$(_cdwin_unix "$raw")" || { echo "cdwin: 无法解析路径 '$raw'" >&2; return 2; }
    fi

    if [ ! -d "$dest" ]; then
        echo "cdwin: 目录不存在：$dest" >&2
        return 1
    fi

    builtin cd "$dest"
}

# 让 cd 也支持 -win / --win 开关；其它用法完全交给内建 cd
cd() {
    case "${1:-}" in
        -win|--win) shift; cdwin "$@" ;;
        *) builtin cd "$@" ;;
    esac
}

# 当前目录（或指定路径）的 Windows 形式
winpath() {
    local p="${1:-$PWD}" u
    case "$p" in
        /*) u="$p" ;;
        *)  u="$(_cdwin_unix "$p")" || { echo "winpath: 无法解析 '$p'" >&2; return 2; } ;;
    esac
    if command -v wslpath >/dev/null 2>&1; then
        wslpath -w "$u" 2>/dev/null && return 0
    fi
    # 兜底：没有 wslpath 时自己把 /mnt/c/... 还原成 C:\...
    case "$u" in
        /mnt/[A-Za-z]|/mnt/[A-Za-z]/*)
            local d rest
            d="$(printf '%s' "${u:5:1}" | tr 'a-z' 'A-Z')"
            rest="${u:6}"
            printf '%s:%s\n' "$d" "${rest//\//\\}"
            return 0 ;;
    esac
    echo "winpath: 无法转换 '$u'" >&2
    return 1
}

# 用资源管理器打开
winopen() {
    local w
    w="$(winpath "${1:-.}")" || return 1
    if [ ! -e /proc/sys/fs/binfmt_misc/WSLInterop ]; then
        echo "winopen: WSL 互操作当前不可用（binfmt_misc 里没有 WSLInterop）。" >&2
        echo "         可试：wsl --shutdown 后重开终端；或在 root 下执行" >&2
        echo "         echo ':WSLInterop:M::MZ::/init:PF' > /proc/sys/fs/binfmt_misc/register" >&2
        echo "         路径：$w" >&2
        return 1
    fi
    explorer.exe "$w" >/dev/null 2>&1 || true
}

# ---- 补全（仅 bash；zsh 请自行补 compdef） ----
_cdwin_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}" out=() c
    if [[ "$cur" =~ ^[A-Za-z]: ]]; then
        local drive="${cur:0:1}" rest="${cur:2}"
        rest="${rest//\\//}"
        rest="${rest#/}"
        local base="/mnt/${drive,,}" dir part
        if [[ "$rest" == */ ]]; then
            dir="$base/${rest%/}"; dir="${dir%/}"; part=""
        elif [[ "$rest" == */* ]]; then
            dir="$base/${rest%/*}"; part="${rest##*/}"
        else
            dir="$base"; part="$rest"
        fi
        while IFS= read -r c; do
            [ -n "$c" ] || continue
            local rel="${c#"$base"}"; rel="${rel#/}"
            out+=("${drive}:/${rel}/")
        done < <(compgen -d -- "${dir%/}/${part}" 2>/dev/null)
    elif [ -z "$cur" ]; then
        out=( "C:/" "D:/" "E:/" "F:/" "G:/" "H:/" "I:/" "J:/" )
    else
        COMPREPLY=( $(compgen -f -- "$cur") )
        return 0
    fi
    COMPREPLY=( "${out[@]// /\\ }" )
    compopt -o nospace 2>/dev/null || true
}

_cd_dispatch() {
    case "${COMP_WORDS[1]}" in
        -win|--win) _cdwin_complete ;;
        *) if declare -F _cd >/dev/null; then _cd "$@"; else COMPREPLY=(); fi ;;
    esac
}

if [ -n "${BASH_VERSION:-}" ] && command -v complete >/dev/null 2>&1; then
    complete -o default -F _cdwin_complete cdwin
    complete -o default -F _cd_dispatch cd
fi
