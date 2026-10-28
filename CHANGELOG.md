# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 与 [语义化版本](https://semver.org/lang/zh-CN/)。

## [1.0.0] - 2026-10-28

### 新增

- `cdwin`：用 Windows 路径直接跳转（`\` 与 `/` 均可，盘符大小写不敏感）
- `cd -win <路径>`：通过 `cd` 的开关调用，`cd` 其余行为保持不变
- `winpath`：反查 Windows 形式路径（默认当前目录）
- `winopen`：用资源管理器打开当前目录，互操作缺失时给出可执行的修复提示
- Tab 补全：`cdwin` 与 `cd -win` 均可补全 Windows 路径（输出正斜杠形式以规避 bash 转义）
- 反斜杠被吃掉的形态识别与提示（避免误报"目录不存在"）
- 无参数时取 Windows 用户目录：`cmd.exe` → `NTUSER.DAT` 扫描 → `Public` 三级兜底
- `install.sh`：安装 / 升级 / `--uninstall`，自动备份启动文件，幂等
- `tests/run.sh`：WSL 全套用例 + 普通 Linux 可移植子集
