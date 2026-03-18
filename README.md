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

如果你想通过远程 `curl` 安装，安装脚本本身必须能继续下载仓库里的 `bin/autosshfs` 和 `share/autosshfs/config.sh.example`。因此远程模式需要提供仓库的 raw 基础地址。

公开仓库示例：

```bash
curl -fsSL <raw-base-url>/install.sh | bash -s -- install --repo-base <raw-base-url>
```

私有仓库示例：

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
"名称|用户名|主机|远程路径|本地挂载点|端口"
```

示例：

```bash
SSHFS_ENTRIES=(
  "signal-server-home|alice|signal-server|/home/alice|$HOME/mount/signal-server|22"
  "signal-server-data|alice|signal-server|/data|$HOME/mount/signal-server-data|22"
)
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

- 建议先运行：

```bash
autosshfs doctor
```

### Linux

- 某些环境下 `allow_other` 需要启用 `/etc/fuse.conf` 中的 `user_allow_other`
- 卸载依赖 `fusermount`
