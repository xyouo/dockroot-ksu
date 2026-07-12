# DockRoot 容器 for KernelSU

这是一个实验性的 KernelSU/APatch/Magisk 模块，用于在已 Root 的 ARM64 Android 设备上直接运行 DockRoot 与 ruri，不依赖额外的 Debian/Ubuntu chroot 模块。

它不是完整 Docker Engine。DockRoot 会拉取 OCI/Docker 镜像、解包为 rootfs，再通过 ruri 启动。容器使用宿主网络，不支持 Docker bridge、`-p` 端口映射、Docker Compose 或 Docker API。

## 当前功能

- 仅支持 ARM64 Android。
- 从 DockRoot 上游下载运行环境并校验固定 SHA-256。
- 拉取、运行、停止和查看容器。
- 查看 ruri 原始运行日志。
- 配置容器开机自启。
- 输出架构、SELinux、文件系统和挂载环境诊断。
- 卸载模块时保留容器数据，防止误删。

模块不会在 Release 中重新分发 DockRoot/ruri 二进制。首次安装运行环境时，手机会直接访问第三方上游下载；DockRoot 仓库目前没有明确许可证，请自行判断是否接受。

## 安装与首次测试

刷入模块并重启手机，然后在 Termux 等终端执行：

```sh
su -c '/data/adb/modules/dockroot_ksu/bin/drctl doctor'
su -c '/data/adb/modules/dockroot_ksu/bin/drctl install-runtime'
su -c '/data/adb/modules/dockroot_ksu/bin/drctl pull library/alpine:latest alpine'
su -c '/data/adb/modules/dockroot_ksu/bin/drctl run alpine /bin/ash'
```

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

## 数据与配置

- 配置：`/data/adb/dockroot/config.env`
- 镜像和容器：`/data/adb/dockroot/data`
- 自启列表：`/data/adb/dockroot/autostart.list`
- 模块日志：`/data/adb/dockroot/logs/service.log`

不要把容器 rootfs 放到 `/sdcard`。Android 共享存储不能正确保存 Linux 权限和符号链接。建议使用 `/data`，或者已正确挂载的 Ext4 外置存储。

## 重要限制

- 容器接近特权运行，隔离能力不能与标准 Docker 相比。
- 所有服务共享手机网络和端口，必须自行避免端口冲突。
- Android 的 Doze、厂商后台冻结和温控策略可能延后任务或终止后台服务。
- 首版不提供 WebUI，先验证设备兼容性和运行稳定性。
- 如果上游二进制更新导致 SHA-256 改变，模块会拒绝执行未知文件，需要先在仓库更新校验值。

## 上游项目

- DockRoot：https://github.com/kspeeder/dockroot
- ruri：https://github.com/RuriOSS/ruri
