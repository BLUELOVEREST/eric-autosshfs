# autosshfs

一个跨平台的 `sshfs` 自动挂载工具，支持 macOS 和 Ubuntu/Debian。

它把机器相关配置放在 `~/.config/autosshfs/config.sh`，程序本身只负责：

- 按网络环境决定是否允许挂载
- 批量挂载 / 卸载
- 按名称挂载 / 卸载
- 自动检测未挂载项并补挂载

## 安装

### 安装脚本

```bash
./install.sh install
```

安装脚本会：

- 把命令安装到 `~/.local/bin/autosshfs`
- 把配置模板安装到 `~/.local/share/autosshfs/config.sh.example`

默认不会自动安装系统依赖。这个工具现在更偏向“先诊断环境，再按平台处理依赖”，因为尤其在 macOS 上，`macFUSE` 往往还需要人工授权系统扩展。

如果你想安装到其他前缀：

```bash
./install.sh install --prefix /usr/local
```

如果你明确希望脚本尝试安装依赖：

```bash
./install.sh install --install-deps
```

如果你想检查环境和当前安装状态：

```bash
./install.sh check
```

如果你想更新当前安装：

```bash
./install.sh update
```

如果你想卸载当前安装：

```bash
./install.sh uninstall
```

如果你连用户配置也要一起删除：

```bash
./install.sh uninstall --purge-config
```

如果你想通过远程 `curl` 安装，默认会使用这个 GitHub 仓库的 raw 地址继续下载 `bin/autosshfs` 和 `share/autosshfs/config.sh.example`。

直接安装：

```bash
curl -fsSL https://raw.githubusercontent.com/BLUELOVEREST/eric-autosshfs/main/install.sh | bash -s -- install
```

直接更新：

```bash
curl -fsSL https://raw.githubusercontent.com/BLUELOVEREST/eric-autosshfs/main/install.sh | bash -s -- update
```

如果你想指定其他分支、tag 或 fork，可以显式传 `--repo-base`：

```bash
curl -fsSL https://raw.githubusercontent.com/BLUELOVEREST/eric-autosshfs/main/install.sh | \
  bash -s -- install \
    --repo-base https://raw.githubusercontent.com/BLUELOVEREST/eric-autosshfs/main
```

如果你以后改回私有仓库，也可以继续用认证头：

```bash
export AUTOSSHFS_AUTH_HEADER='Authorization: token <your-token>'
curl -fsSL -H "$AUTOSSHFS_AUTH_HEADER" <raw-base-url>/install.sh | \
  bash -s -- install --repo-base <raw-base-url>
```

其中 `<raw-base-url>` 应该指向仓库某个分支或 tag 的原始文件根路径，而不是仓库主页。例如它下面应该能访问：

```text
<raw-base-url>/install.sh
<raw-base-url>/bin/autosshfs
<raw-base-url>/share/autosshfs/config.sh.example
```

## 配置与验证顺序

建议按下面顺序做，而不是装完就直接挂载：

1. 初始化配置

```bash
autosshfs init-config
```

2. 编辑 `~/.config/autosshfs/config.sh`
3. 确认每个目标主机已经配置好 SSH 免密登录，并且你可以手工执行：

```bash
ssh <host>
```

4. 运行诊断：

```bash
autosshfs doctor
```

5. 诊断通过后再挂载：

```bash
autosshfs mount-all
```

如果你后续启用 `systemd --user` 定时自动补挂载，不建议跳过上面这些前置步骤。至少要先保证：

- `autosshfs doctor` 已通过关键检查
- `ssh-add -l` 能看到对应私钥
- `systemctl --user` 可用
- `SSH_AUTH_SOCK` 在用户 session 中可见

启用后建议执行这些验证命令：

```bash
systemctl --user daemon-reload
systemctl --user enable --now autosshfs.timer
systemctl --user status autosshfs.timer --no-pager
systemctl --user start autosshfs.service
systemctl --user status autosshfs.service --no-pager
journalctl --user -u autosshfs.service -n 50 --no-pager
```

## 初始化配置

```bash
autosshfs init-config
```

然后编辑：

```bash
~/.config/autosshfs/config.sh
```

配置中的挂载项格式为：

```bash
"名称(=SSH Host Alias)|远程路径"
```

示例：

```bash
MOUNT_BASE_DIR="$HOME/mount"

SSHFS_ENTRIES=(
  "signal-server-home|/home/alice"
  "signal-server-data|/data"
)
```

这样会自动挂载到：

```text
$HOME/mount/signal-server-home
$HOME/mount/signal-server-data
```

如果你想指定端口，也可以写成：

```bash
"signal-server-home|/home/alice|2222"
```

如果你想覆盖默认挂载目录：

```bash
"signal-server-home|/home/alice|$HOME/custom/path|22"
```

这要求你的 `~/.ssh/config` 里已经有对应的 `Host signal-server-home` 配置，`User`、`HostName`、`Port`、`IdentityFile` 等都由 SSH 自己解析。

如果你暂时不想依赖 `~/.ssh/config`，仍然兼容旧格式：

```bash
"signal-server-home|alice|signal-server|/home/alice"
"signal-server-home|alice|signal-server|/home/alice|2222"
"signal-server-home|alice|signal-server|/home/alice|$HOME/custom/path|22"
```

## 命令

```bash
autosshfs init-config
autosshfs doctor
autosshfs mount-all
autosshfs umount-all
autosshfs auto-remount
autosshfs mount signal-server-home
autosshfs umount signal-server-home
autosshfs status
autosshfs list
```

`doctor` 会检查：

- 配置文件是否存在
- `sshfs`、`fusermount`、`mountpoint` 等依赖
- macOS 上 `macFUSE` 是否看起来已安装
- 当前网络是否命中配置规则

## 网络匹配

默认模板使用 `NETWORK_MODE="match"`。只要以下任意一项匹配，就允许挂载：

- `NETWORK_GATEWAYS`
- `NETWORK_DNS`
- `NETWORK_IP_PREFIXES`
- `NETWORK_INTERFACES`
- `NETWORK_SSIDS`（仅 macOS）

如果你不想做网络判断：

```bash
NETWORK_MODE="always"
```

## 注意事项

### macOS

- `macFUSE` 安装后通常还需要在系统设置里允许相关系统扩展
- `sshfs` 常见安装方式：

```bash
brew install --cask macfuse
brew install gromgit/fuse/sshfs-mac
```

- `autosshfs` 默认会为 macOS 挂载追加 `noappledouble,noapplexattr`，尽量避免在 Linux 侧看到 `._*` 文件
- 如果你还想补充其他 macOS 挂载参数，可以在配置里设置 `MACOS_SSHFS_EXTRA_OPTIONS`
- 建议先运行：

```bash
autosshfs doctor
```

### Linux

- 某些环境下 `allow_other` 需要启用 `/etc/fuse.conf` 中的 `user_allow_other`
- 卸载依赖 `fusermount`
