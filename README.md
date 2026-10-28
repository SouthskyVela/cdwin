# cdwin

> 在 WSL 里用 **Windows 路径**直接 `cd` —— 不用再 `/mnt/c/Users/...` 一层层敲。

```bash
cdwin 'C:\Users\me\Desktop'    # 资源管理器里"复制文件地址"，直接粘进来
cd -win 'D:\project\data'      # 走 cd 的开关，肌肉记忆不变
cdwin                          # 不带参数 → 回到 Windows 用户目录
winpath                        # 反查：当前目录的 Windows 形式
winopen                        # 资源管理器打开当前目录
```

```
uvela@uni-navigator:~$ cdwin 'G:\on_this_pc'
uvela@uni-navigator:/mnt/g/on_this_pc$ winpath
G:\on_this_pc
```

## 为什么需要它

WSL 里访问 Windows 盘符要写 `/mnt/c/...`，日常三件事很烦：

1. **路径对不上**：资源管理器给你的是 `C:\Users\me\Desktop`，`cd` 不认；
2. **反斜杠被吃**：不加引号时 bash 把 `\` 当转义符，`C:\Users\me` 会变成 `C:Usersme`，报错还看不出是为什么；
3. **空格**：`Program Files`、`My Documents` 这类路径必须整体引用，手打容易漏。

`cdwin` 把这三件事一次性挡掉：粘贴 → 回车，完事。

## 安装

**方式一（推荐）**

```bash
git clone https://github.com/SouthskyVela/cdwin.git ~/.cdwin-src
cd ~/.cdwin-src && ./install.sh
```

**方式二（一行）**

```bash
curl -fsSL https://raw.githubusercontent.com/SouthskyVela/cdwin/main/install.sh | bash
```

两种方式做的事一样：

- 脚本装到 `~/.local/share/cdwin/cdwin.sh`（可用 `--dir` 改）
- 在 `~/.bashrc` 末尾追加标记块 `# >>> cdwin >>>` … `# <<< cdwin <<<`（可用 `--rc` 改）
- 改之前自动备份为 `~/.bashrc.cdwin.bak`
- 可重复执行，等于升级

装完执行 `source ~/.bashrc`，或重开终端。

**卸载**

```bash
~/.cdwin-src/install.sh --uninstall     # 或用 curl 再跑一次加 --uninstall
```

## 用法

| 命令 | 作用 |
|---|---|
| `cdwin <Windows 路径>` | 跳转。`\` 和 `/` 都认，盘符大小写无所谓 |
| `cd -win <Windows 路径>` | 同上，等价写法 |
| `cdwin` | 回到 Windows 用户目录（`%USERPROFILE%`） |
| `winpath [路径]` | 输出 Windows 形式，默认当前目录 |
| `winopen [路径]` | 用资源管理器打开，默认当前目录 |
| `cdwin -v` / `cdwin -h` | 版本 / 帮助 |

**Tab 补全**：`cdwin <Tab>`、`cd -win <Tab>` 都能补 Windows 路径。补全项输出**正斜杠**形式（如 `C:/Program\ Files/`），因为反斜杠在未加引号时会被 bash 吃掉。

**环境变量**

| 变量 | 作用 |
|---|---|
| `CDWIN_WINHOME` | 覆盖"无参数时的默认目录"，可写 Windows 或 Linux 路径 |
| `CDWIN_HOME` | 安装目录（仅安装脚本用） |
| `CDWIN_RC` | 要写入的启动文件（仅安装脚本用） |

## 它是怎么做的

- 路径转换优先用 `wslpath -u`（WSL 自带），失败时按盘符手工兜底（`D:\x` → `/mnt/d/x`），所以没装 `wslpath` 也能用；
- 真跳转用 `builtin cd`，不做任何路径拼接或 `cd` 模拟；
- `cd` 只是被包了一层，**只拦 `-win` / `--win`**，`cd -`、`cd ~`、`cd` 无参数等行为完全不变；
- 识别"反斜杠被吃"的典型形态（盘符后直接跟字符），直接提示加引号，而不是丢一个"目录不存在"；
- 无参数时取 Windows 用户目录：先问 `cmd.exe`（互操作正常时最准），失败则扫 `/mnt/c/Users/*/NTUSER.DAT` 挑最近使用的真实用户目录，再退 `/mnt/c/Users/Public`；
- 补全注册走 `complete`，普通 `cd` 仍用 bash-completion 的 `_cd`，不打架。

## 常见问题

**Q：为什么必须加引号？**
不加引号时 `\` 是 bash 的转义符，`C:\Users\me` 会被解释成 `C:Usersme`。`cdwin` 会检测这种形态并提示，但最省事的办法永远是加单引号——资源管理器"复制文件地址"出来的就是带引号的，直接粘。

**Q：`winopen` 报"WSL 互操作当前不可用"？**
`explorer.exe`/`cmd.exe` 依赖 WSL 的 binfmt 互操作。若 `/proc/sys/fs/binfmt_misc/WSLInterop` 不存在，可在 root 下重新注册：

```bash
echo ':WSLInterop:M::MZ::/init:PF' > /proc/sys/fs/binfmt_misc/register
```

或 `wsl --shutdown` 后重开终端。注意 `cdwin` 本身**不依赖**互操作，只有 `winopen` 依赖。

**Q：只有 C 盘 / D 盘没挂载？**
WSL 默认自动挂载所有盘符。若某个盘不可见，先确认 `ls /mnt/d`，必要时在 `/etc/wsl.conf` 的 `[automount]` 里调整（改完要 `wsl --shutdown`）。

**Q：为什么不干脆把挂载点改成 `/`（`automount root=/`）？**
那样路径会变成 `/c/Users/...`，少一层 `/mnt` 但需要重启 WSL，并且会把所有既有脚本里的 `/mnt/...` 打断。`cdwin` 不改变任何挂载配置，风险为零。

**Q：zsh 能用吗？**
函数本体是 POSIX 风格 bash，zsh 下 `cdwin`/`winpath`/`winopen` 基本可用；补全只做了 bash 版本，zsh 用户可自行 `compdef`。

## 兼容性

- WSL2 + bash 4.0 以上（Ubuntu 20.04 / 22.04 实测；Debian、Kali 等同理）
- Windows 10 / 11
- 不依赖 `root`，安装在用户目录

## 开发

```bash
bash tests/run.sh      # 在 WSL 里跑全套；在普通 Linux 上自动跳过 /mnt 相关用例
```


## License

[MIT](LICENSE) © 2026 SouthskyVela

---

## English (short)

`cdwin` lets you `cd` with Windows paths inside WSL:

```bash
cdwin 'C:\Users\me\Desktop'
cd -win 'D:\data'
cdwin            # → C:\Users\<you>
```

Install: `git clone https://github.com/SouthskyVela/cdwin.git ~/.cdwin-src && ~/.cdwin-src/install.sh`
(or `curl -fsSL https://raw.githubusercontent.com/SouthskyVela/cdwin/main/install.sh | bash`).

It converts Windows paths with `wslpath` (with a drive-letter fallback), wraps `cd` only for the `-win` flag, provides Bash completion, and warns when pasted backslashes were eaten by the shell. Tested on WSL2 + Ubuntu 20.04/22.04. MIT licensed.
