#!/usr/bin/env bash
# cdwin 自测：在有 /mnt/c 的 WSL 上跑全套，在普通 Linux（CI）上跑可移植子集
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../cdwin.sh
. "$HERE/../cdwin.sh"

pass=0; fail=0; skip=0
ok()   { pass=$((pass + 1)); printf '  \033[32mok\033[0m    %s\n' "$1"; }
bad()  { fail=$((fail + 1)); printf '  \033[31mFAIL\033[0m  %s\n' "$1"; [ -n "${2:-}" ] && printf '          %s\n' "$2"; }
skipped() { skip=$((skip + 1)); printf '  \033[33mskip\033[0m  %s\n' "$1"; }
eq()   { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3" "期望 [$2] 实际 [$1]"; fi; }
rc_is() { local want="$1"; shift; "$@" >/dev/null 2>&1; local got=$?; eq "$got" "$want" "$*  → 退出码 $want"; }

ON_WSL=0
[ -d /mnt/c ] && ON_WSL=1

echo "== 1. 路径转换（可移植）=="
eq "$(_cdwin_unix 'C:\Users\me')"        '/mnt/c/Users/me'    '反斜杠盘符路径'
eq "$(_cdwin_unix 'D:/data/run1')"       '/mnt/d/data/run1'   '正斜杠盘符路径'
eq "$(_cdwin_unix 'g:\')"                '/mnt/g/'            '盘符根（小写）'
eq "$(_cdwin_unix '/home/someone')"      '/home/someone'      'Linux 路径透传'
eq "$(_cdwin_unix '..')"                 '..'                 '相对路径透传'
eq "$(_cdwin_unix '~/work')"             '~/work'             '~ 透传'
eq "$(_cdwin_unix 'sub/dir')"            'sub/dir'            '相对路径原样透传'

echo "== 2. 错误处理（可移植）=="
rc_is 2 cdwin 'C:Windows'          # 反斜杠被 bash 吃掉的典型形态
rc_is 1 cdwin 'Z:\no_such_dir_xyz' # 目录不存在
rc_is 1 cdwin ':::bad:::'          # 非路径字符串原样交给 cd，由 cd 报错（退出码 1）
cdwin -v | grep -q 'cdwin ' && ok 'cdwin -v 输出版本' || bad 'cdwin -v 输出版本'
cdwin -h | grep -q 'winpath' && ok 'cdwin -h 显示帮助' || bad 'cdwin -h 显示帮助'

echo "== 3. cd 包装不破坏原行为（可移植）=="
( cd /tmp && cd /usr && cd - >/dev/null && [ "$PWD" = "/tmp" ] ) && ok 'cd - 仍可回上一个目录' || bad 'cd - 仍可回上一个目录'
( cd /usr && cd / >/dev/null && [ "$PWD" = "/" ] ) && ok '普通 cd 正常' || bad '普通 cd 正常'

echo "== 4. 补全函数（bash）=="
if [ -n "${BASH_VERSION:-}" ]; then
    declare -F _cdwin_complete >/dev/null && ok '_cdwin_complete 已定义' || bad '_cdwin_complete 已定义'
    declare -F _cd_dispatch >/dev/null && ok '_cd_dispatch 已定义' || bad '_cd_dispatch 已定义'
else
    skipped '非 bash，跳过补全检查'
fi

if [ "$ON_WSL" -eq 1 ]; then
    echo "== 5. 真实跳转（WSL）=="
    ( cdwin 'C:\Windows' >/dev/null 2>&1 && [ "$PWD" = "/mnt/c/Windows" ] ) \
        && ok "cdwin 'C:\\Windows'" || bad "cdwin 'C:\\Windows'"
    ( cd -win 'C:\Windows\System32' >/dev/null 2>&1 && [ "$PWD" = "/mnt/c/Windows/System32" ] ) \
        && ok "cd -win 带多级路径" || bad "cd -win 带多级路径"
    ( cdwin >/dev/null 2>&1 && [ -d "$PWD" ] && [ "${PWD#/mnt/c/Users/}" != "$PWD" ] ) \
        && ok "cdwin 无参数 → Windows 用户目录" || bad "cdwin 无参数 → Windows 用户目录"
    ( cd /mnt/c/Windows && [ "$(winpath)" = 'C:\Windows' ] ) \
        && ok 'winpath 反向转换' || bad 'winpath 反向转换'
    # 带空格路径：优先用真实存在的 Program Files
    if [ -d '/mnt/c/Program Files' ]; then
        ( cdwin 'C:\Program Files' >/dev/null 2>&1 && [ "$PWD" = '/mnt/c/Program Files' ] ) \
            && ok '带空格路径' || bad '带空格路径'
    else
        skipped '带空格路径（无 Program Files）'
    fi
else
    echo "== 5. 真实跳转（WSL）=="
    skipped '未检测到 /mnt/c，跳过真实跳转用例'
fi

echo
printf '结果：通过 %d，失败 %d，跳过 %d\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ] || exit 1
