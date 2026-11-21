# smartdns-openwrt

面向 **OpenWrt 21.02** 分支的 smartdns 打包仓库，包含 smartdns 服务端、Web 面板及 LuCI 应用。
服务端与面板已拆分为两个独立软件包，可分别安装、升级。

## 包结构

| 软件包 | 内容 | 依赖 |
| --- | --- | --- |
| `smartdns` | `/usr/sbin/smartdns`、init 脚本、`/etc/config/smartdns` 与默认配置、OpenSSL 3.x 运行库 | `libc`、`libpthread`、`zlib` |
| `smartdns-ui` | Web 面板：`/usr/lib/smartdns_ui.so` 与 `/usr/share/smartdns/wwwroot` | `smartdns` |
| `luci-app-smartdns` | LuCI 配置页面 | `smartdns`，可选 `smartdns-ui` |

安装 `luci-app-smartdns` 时，`Include smartdns-ui` 选项（`PACKAGE_luci-app-smartdns_INCLUDE_smartdns_ui`，**默认关闭**）决定是否一并安装面板。
默认只安装 DNS 服务端；需要面板时，在 menuconfig 中勾选该子选项，或在 `.config` 中写入 `CONFIG_PACKAGE_luci-app-smartdns_INCLUDE_smartdns_ui=y`（等价于直接选中 `CONFIG_PACKAGE_smartdns-ui=y`）。
未安装面板时，LuCI 页面不会显示 Web 面板相关设置。
若曾开启 Web 面板后又卸载 `smartdns-ui`，init 脚本会检测到插件缺失并跳过面板配置，不影响 DNS 服务启动。

## 为什么使用预构建二进制

本仓库直接使用 [PikuZheng/smartdns](https://github.com/PikuZheng/smartdns) 发布的 `smartdns_with_ui` 预构建包，其中已包含 **OpenSSL 3.5.8 (LTS)** 与 **smartdns-ui**。原因如下：

- **OpenSSL 版本**：OpenWrt 21.02 自带的 OpenSSL 为 1.1.1，缺少 QUIC / HTTP3 所需的 TLS 接口，因此 **不支持 DoQ / DoH3**。预构建包内置 OpenSSL 3.5.8 LTS，并以 `/usr/lib/smartdns/` 下的独立库文件提供，不再依赖系统 OpenSSL，从而补齐 DoQ / DoH3 支持。
- **Rust 工具链**：`smartdns-ui` 由 Rust 编写，而 OpenWrt 21.02 的软件源中没有 Rust，无法在 21.02 上现场编译面板，只能使用预构建产物。

代价是只能覆盖官方提供预构建的架构：`aarch64`、`arm`（armv7）、`x86_64`。其他架构请在 Makefile 中补充对应的 `PKG_ARCH` 与 `PKG_HASH`，或自行交叉编译。

## 升级版本

修改 `smartdns/Makefile` 中的 `PKG_VERSION`，并按架构更新 `PKG_HASH`（对应 release 资产 `smartdns_with_ui.1.2026.v<版本>.<架构>.tar.gz`）。
两个软件包共用同一压缩包，版本与哈希只需维护一处。

## 构建

```sh
# 在 OpenWrt 21.02 源码树中
ln -s /path/to/smartdns-openwrt/smartdns feeds/package/smartdns
ln -s /path/to/smartdns-openwrt/luci-app-smartdns feeds/luci/applications/luci-app-smartdns

make menuconfig   # Network -> IP Addresses and Names -> smartdns；LuCI -> Applications -> luci-app-smartdns -> Include smartdns-ui
make package/smartdns/compile V=s
make package/luci-app-smartdns/compile V=s
```

`Include smartdns-ui` 默认关闭：只装服务端时无需额外操作；需要 Web 面板时，请在选择 `luci-app-smartdns` 后勾选该子选项，或直接选中 `smartdns-ui`（两者等价），否则 `smartdns-ui` 不会被编译进固件。
