# DockRoot 容器 for KernelSU

这是一个实验性的 KernelSU/APatch/Magisk 模块，用于在已 Root 的 ARM64 Android 设备上直接运行 DockRoot 与 ruri，不依赖额外的 Debian/Ubuntu chroot 模块。

它不是完整 Docker Engine。DockRoot 会拉取 OCI/Docker 镜像、解包为 rootfs，再通过 ruri 启动。容器使用宿主网络，不支持 Docker bridge、`-p` 端口映射、Docker Compose 或 Docker API。

## 当前功能

- 仅支持 ARM64 Android。
- 从 DockRoot 上游下载运行环境并校验固定 SHA-256。
- 拉取、运行、停止和查看容器。
- 查看 ruri 原始运行日志。
- 配置容器开机自启。
- 使用 Compose Lite 配置文件声明镜像、卷、环境变量和自启策略。
- 输出架构、SELinux、文件系统和挂载环境诊断。
- 通过独立 mount namespace 为 DockRoot 提供 DNS，不修改 Android 全局网络配置。
- 卸载模块时保留容器数据，防止误删。

模块不会在 Release 中重新分发 DockRoot/ruri 二进制。首次安装运行环境时，手机会直接访问第三方上游下载；DockRoot 仓库目前没有明确许可证，请自行判断是否接受。

## 安装与首次测试

刷入模块并重启手机，然后在 Termux 等终端执行：

```sh
su -c '/data/adb/modules/dockroot_ksu/bin/drctl pull alpine:latest alpine'
su -c '/data/adb/modules/dockroot_ksu/bin/drctl run alpine /bin/ash'
```

`pull` 会在本机第一次使用时自动下载并校验运行环境。`doctor` 和 `install-runtime` 仅用于诊断或手动预安装，不是每次安装模块都必须执行。

重启后模块也会把 `drctl` 放入 root 命令路径，因此通常可以简写为 `su -c 'drctl doctor'`。上面的完整路径便于排除 PATH 差异。

进入 Alpine 后可测试：

```sh
cat /etc/os-release
uname -m
exit
```

后台运行、查看状态和停止：

```sh
su -c '/data/adb/modules/dockroot_ksu/bin/drctl run -d alpine'
su -c '/data/adb/modules/dockroot_ksu/bin/drctl ps alpine'
su -c '/data/adb/modules/dockroot_ksu/bin/drctl stop alpine'
```

设置开机自启：

```sh
su -c '/data/adb/modules/dockroot_ksu/bin/drctl autostart add alpine'
su -c '/data/adb/modules/dockroot_ksu/bin/drctl autostart list'
```

## Compose Lite 固定配置

每个容器使用一个容易备份和编辑的配置文件：

```text
/data/adb/dockroot/stacks/<容器名>.conf
```

支持以下字段：

- `IMAGE=`：镜像名称，必填。
- `AUTOSTART=0|1`：是否随手机开机启动。
- `VOLUME=宿主绝对路径:容器绝对路径[:ro]`：可以重复填写。
- `ENV=KEY=VALUE`：可以重复填写。
- `HOSTNAME=`：可选容器主机名。
- `WORKDIR=`：可选容器工作目录，必须是绝对路径。

DockRoot 只有 host 网络，因此不支持 Compose 的 `ports`、独立网络、`depends_on` 等字段。镜像监听的端口会直接占用手机端口。

常用命令：

```sh
drctl stack list
drctl stack path
drctl apply openlist
drctl up openlist
drctl down openlist
drctl restart openlist
drctl logs openlist 100
```

`apply` 只拉取缺失镜像并更新固定配置，不会启动长期服务。`up` 会应用配置后后台启动。修改 `.conf` 后再次执行 `drctl up <容器名>` 即可生效。

### OpenList 标准完整版示例

创建内置模板：

```sh
su -c 'drctl stack create openlist'
su -c 'drctl up openlist'
```

生成的 `/data/adb/dockroot/stacks/openlist.conf` 内容为：

```ini
IMAGE=openlistteam/openlist:latest
AUTOSTART=1
VOLUME=/data/adb/dockroot/volumes/openlist:/opt/openlist/data
ENV=UMASK=022
```

这里使用 OpenList 官方标准完整版 `latest`，不是 `lite` 精简版。OpenList 使用 host 网络，默认面板地址为 `http://127.0.0.1:5244`。业务配置和数据库保存在 `/data/adb/dockroot/volumes/openlist`，重新拉取镜像不会删除它们。

DockRoot 当前版本在拉取时会丢失 `latest-aio` 等非 `latest` 标签，因此模块会拒绝静默拉错镜像。v0.2.0 创建的 OpenList 配置会在首次 `apply/up` 时自动迁移为实际已拉取的 `latest`。待上游修复标签处理后，再恢复 AIO 模板支持。

OpenList 4.1 之后可能以容器内 UID 1001 运行。模块会放宽具体卷目录的权限以允许该用户写入；其上级 `/data/adb/dockroot` 仍保持仅 root 可访问。

### 青龙面板示例

创建青龙配置时可以直接指定端口，例如使用 5900：

```sh
su -c 'drctl stack create qinglong 5900'
su -c 'drctl up qinglong'
```

生成的 `/data/adb/dockroot/stacks/qinglong.conf` 主要内容为：

```ini
IMAGE=whyour/qinglong:latest
AUTOSTART=1
HOSTNAME=qinglong
VOLUME=/data/adb/dockroot/volumes/qinglong:/ql/data
ENV=QlPort=5900
ENV=QlBaseUrl=/
ENV=TZ=Asia/Shanghai
```

青龙使用 host 网络，因此面板地址是 `http://127.0.0.1:5900`。请确保该端口没有被其他青龙模块或面板占用。青龙的配置、任务、日志和依赖保存在 `/data/adb/dockroot/volumes/qinglong`，覆盖升级模块或重新拉取镜像不会删除。

如果创建模板时省略端口，将使用青龙默认的 5700：

```sh
su -c 'drctl stack create qinglong'
```

## 数据与配置

- 配置：`/data/adb/dockroot/config.env`
- 镜像和容器：`/data/adb/dockroot/data`
- Compose Lite 配置：`/data/adb/dockroot/stacks`
- 持久化业务数据：`/data/adb/dockroot/volumes`
- 自启列表：`/data/adb/dockroot/autostart.list`
- 模块日志：`/data/adb/dockroot/logs/service.log`

不要把容器 rootfs 放到 `/sdcard`。Android 共享存储不能正确保存 Linux 权限和符号链接。建议使用 `/data`，或者已正确挂载的 Ext4 外置存储。

## 清理旧文件

先预览模块能够安全识别的残留：

```sh
su -c 'drctl cleanup'
```

确认列表后删除：

```sh
su -c 'drctl cleanup --yes'
```

该命令只删除两类内容：

- `/data/adb/dockroot/data` 中没有 `rootfs` 的失败拉取目录，例如之前失败产生的 `alpine2`。
- `/data/adb/dockroot/bin` 中遗留的 `.download.*` 下载残片。

清理前还会校验 DockRoot 受管标记，并拒绝 `/`、`/data`、`/system` 等系统级 `DATA_ROOT`，避免误配置扩大删除范围。

以下目录仍在使用，不应作为旧版本垃圾删除：

- `/data/adb/dockroot/bin`：DockRoot 和 ruri 运行环境。
- `/data/adb/dockroot/dns-etc`、`cacerts`：Android DNS 与 HTTPS 兼容环境。
- `/data/adb/dockroot/data/<容器名>`：已拉取的容器 rootfs。
- `/data/adb/dockroot/stacks`：固定配置。
- `/data/adb/dockroot/volumes`：容器业务数据。

## 重要限制

- 容器接近特权运行，隔离能力不能与标准 Docker 相比。
- 所有服务共享手机网络和端口，必须自行避免端口冲突。
- Android 的 Doze、厂商后台冻结和温控策略可能延后任务或终止后台服务。
- 首版不提供 WebUI，先验证设备兼容性和运行稳定性。
- 如果上游二进制更新导致 SHA-256 改变，模块会拒绝执行未知文件，需要先在仓库更新校验值。

## 上游项目

- DockRoot：https://github.com/kspeeder/dockroot
- ruri：https://github.com/RuriOSS/ruri
