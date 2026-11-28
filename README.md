# smartdns-openwrt

面向 **OpenWrt 21.02** 分支的 smartdns 打包仓库，包含 smartdns 服务端、Web 面板及 LuCI 应用。
服务端与面板已拆分为两个独立软件包，可分别安装、升级。

## 包结构

| 软件包 | 内容 | 依赖 |
| --- | --- | --- |
| `smartdns` | `/usr/sbin/smartdns`、init 脚本、`/etc/config/smartdns` 与默认配置 | `libc`、`libpthread`、`zlib`；系统 OpenSSL < 3.3 时加 `smartdns-openssl`，≥ 3.3 时加 `libopenssl` |
| `smartdns-openssl` | OpenSSL 3 运行库：`/usr/lib/smartdns/libssl.so.3`、`libcrypto.so.3`（隐藏包，系统 OpenSSL < 3.3 时安装） | `libc` |
| `WebUI` | Web 面板：`/usr/lib/smartdns_ui.so` 与 `/usr/share/smartdns/wwwroot` | `smartdns` |
| `luci-app-smartdns` | LuCI 配置页面 | `smartdns`，可选 `WebUI` |
| `luci-app-smartdns-lite` | 精简版 LuCI 配置页面（生成配置片段交由 `smartdns` 加载） | `smartdns` |

安装 `luci-app-smartdns` 时，`Include WebUI` 选项（`PACKAGE_luci-app-smartdns_INCLUDE_WebUI`，**默认关闭**）决定是否一并安装面板。
默认只安装 DNS 服务端；需要面板时，在 menuconfig 中勾选该子选项，或在 `.config` 中写入 `CONFIG_PACKAGE_luci-app-smartdns_INCLUDE_WebUI=y`（等价于直接选中 `CONFIG_PACKAGE_smartdns-ui=y`）。
未安装面板时，LuCI 页面不会显示 Web 面板相关设置。
若曾开启 Web 面板后又卸载 `smartdns-ui`，init 脚本会检测到插件缺失并跳过面板配置，不影响 DNS 服务启动。

## 关于 luci-app-smartdns-lite

`luci-app-smartdns-lite` 是面向“只做国内分流 / 分流域名”场景的精简配置页面，与 `luci-app-smartdns` 互不冲突，可同时安装。

它本身不运行守护进程，而是把配置页面中的设置生成为 `/var/etc/smartdns/smartdns-lite.conf`，再通过 UCI 把该文件登记到 `smartdns.@smartdns[0].conf_files`，同时按所选模式调整 `enabled`、`port`、`auto_set_dnsmasq`，最后重载 `/etc/init.d/smartdns`。因此：

- 必须先安装 `smartdns` 服务端包（本包依赖已声明）；
- 页面状态栏展示的是 `smartdns` 服务的运行状态；
- 关闭本页面中的 `enabled` 后，会撤销自身生成的配置片段并重载服务。
- 基础设置页还提供测速模式、响应模式、双栈 IP 优选、域名预加载、缓存过期服务、缓存大小、持久化缓存、缓存文件、解析本地主机名、mDNS 查询、强制 AAAA/HTTPS SOA、域名 TTL（含最小/最大值）等解析与缓存选项，语义与完整版一致；默认值也与完整版相同（`cache_size 8000`、`speed_check_mode tcp-syn:443,tcp-syn:80,ping`、`prefetch_domain 1`、`mdns_lookup 1`）。
- 安装 `smartdns-ui` 后，基础设置页会显示 WebUI 选项（启用、端口、数据库目录、日志保存天数）；启用后 `plugin smartdns_ui.so`、`data-dir` 等指令写入本页面的配置片段，运行状态右侧同时出现“打开 WebUI”按钮。

## 为什么使用预构建二进制

本仓库直接使用 [PikuZheng/smartdns](https://github.com/PikuZheng/smartdns) 发布的 `smartdns_with_ui` 预构建包，其中已包含 **OpenSSL 3.5.9 (LTS)** 与 **smartdns-ui**。原因如下：

- **OpenSSL 版本**：OpenWrt 21.02 / 22.03 自带的 OpenSSL 为 1.1.1，缺少 QUIC / HTTP3 所需的 TLS 接口，因此 **不支持 DoQ / DoH3**；预构建包内置 OpenSSL 3.5.9 LTS，从而补齐 DoQ / DoH3 支持。
- **运行库安装策略**：预构建二进制导入了带 `OPENSSL_3.2.0` / `OPENSSL_3.3.0` 版本标记的符号，因此只有系统 OpenSSL ≥ 3.3 时才能直接复用系统库（目前仅 main/SNAPSHOT 的 3.5.x 满足）。21.02（1.1.1）、22.03（1.1.1）、23.05（3.0.19）、24.10（3.0.22）都由隐藏包 `smartdns-openssl` 把两个库安装到 `/usr/lib/smartdns/`。init 脚本启动时设置 `LD_LIBRARY_PATH=/usr/lib/smartdns:/usr/lib:/lib`，因此两种情况都能正确加载。
- **Rust 工具链**：`smartdns-ui` 由 Rust 编写，而 OpenWrt 21.02 的软件源中没有 Rust，无法在 21.02 上现场编译面板，只能使用预构建产物。

只能覆盖官方提供预构建的架构：`aarch64`、`arm`（armv7）、`x86_64`。

## 升级版本

修改 `smartdns/Makefile` 中的 `PKG_VERSION`，并按架构更新 `PKG_HASH`（对应 release 资产 `smartdns_with_ui.1.2026.v<版本>.<架构>.tar.gz`）。
三个软件包共用同一压缩包，版本与哈希只需维护一处。

## 构建

```sh
# 在 OpenWrt 21.02 源码树中
ln -s /path/to/smartdns-openwrt/smartdns feeds/package/smartdns
ln -s /path/to/smartdns-openwrt/luci-app-smartdns feeds/luci/applications/luci-app-smartdns
ln -s /path/to/smartdns-openwrt/luci-app-smartdns-lite feeds/luci/applications/luci-app-smartdns-lite

make menuconfig   # Network -> IP Addresses and Names -> smartdns；LuCI -> Applications -> luci-app-smartdns -> Include smartdns-ui
make package/smartdns/compile V=s
make package/luci-app-smartdns/compile V=s
make package/luci-app-smartdns-lite/compile V=s
```

`Include WebUI` 默认关闭：只装服务端时无需额外操作；需要 Web 面板时，请在选择 `luci-app-smartdns` 后勾选该子选项，或直接选中 `smartdns-ui`（两者等价），否则 `smartdns-ui` 不会被编译进固件。
