# smartdns-openwrt

面向 **OpenWrt 21.02** 分支与 **ucode** 分支（LuCI 24.10 / 25.12 / main）的 smartdns 打包仓库，包含 smartdns 服务端、Web 面板及 LuCI 应用。
服务端、Web 面板、LuCI 页面拆分为独立软件包，可分别安装、升级；完整版与精简版 LuCI 页面共用同一个 `smartdns` 服务端。

## 包结构

| 软件包 | 内容 | 依赖 |
| --- | --- | --- |
| `smartdns` | `/usr/sbin/smartdns`、完整版 init 脚本、`/etc/config/smartdns`、`/etc/smartdns/` 默认配置与示例 | `libc`、`libpthread`、`zlib`；系统 OpenSSL < 3.3 时加 `smartdns-openssl`，≥ 3.3 时加 `libopenssl` |
| `smartdns-openssl` | OpenSSL 3 运行库：`/usr/lib/smartdns/libssl.so.3`、`libcrypto.so.3`（隐藏包，系统 OpenSSL < 3.3 时安装） | `libc` |
| `WebUI` | Web 面板：`/usr/lib/smartdns_ui.so` 与 `/usr/share/smartdns/wwwroot` | `smartdns` |
| `luci-app-smartdns` | 完整版 LuCI 页面（ucode 控制器、中文翻译、菜单、ACL） | `smartdns`，可选 `WebUI` |
| `luci-app-smartdns-lite` | 精简版 LuCI 页面（ucode 控制器、中文翻译、菜单、ACL），以及自身的 `/etc/config/smartdns-lite`、`/etc/init.d/smartdns-lite` | `smartdns` |

init 脚本、`/etc/config/smartdns`、`/etc/smartdns/` 数据文件由 `smartdns` 统一安装；两个 LuCI 页面只包含页面资源（ucode 控制器、翻译、菜单、ACL）与各自的 UCI 配置，避免升级时出现文件所有权冲突。

安装 `luci-app-smartdns` 时，`Include WebUI` 选项（`PACKAGE_luci-app-smartdns_INCLUDE_WebUI`，**默认关闭**）决定是否一并安装面板。
默认只安装 DNS 服务端；需要面板时，在 menuconfig 中勾选该子选项，或在 `.config` 中写入 `CONFIG_PACKAGE_luci-app-smartdns_INCLUDE_WebUI=y`（等价于直接选中 `CONFIG_PACKAGE_smartdns-ui=y`）。
未安装面板时，LuCI 页面不会显示 Web 面板相关设置。
若曾开启 Web 面板后又卸载 `smartdns-ui`，init 脚本会检测到插件缺失并跳过面板配置，不影响 DNS 服务启动。

## 默认配置

完整版与精简版使用相同的默认值（仅写入页面默认值与出厂 UCI 配置；init 脚本中的 `config_get` 兜底值保持原样，避免覆盖已有安装）：

| 选项 | 默认值 |
| --- | --- |
| 测速模式 | `tcp-syn:443,tcp-syn:80,ping` |
| 响应模式 | 最快 Ping（`first-ping`） |
| 双栈 IP 优选 | 开 |
| 域名预加载 | 开 |
| 缓存过期服务 | 开 |
| 缓存大小 | 8000 |
| 持久化缓存 | 开 |
| 解析本地主机名 | 开 |
| mDNS 查询 | 开 |
| 强制 HTTPS SOA | 开 |
| 强制 AAAA SOA | 关 |

上表为**页面默认值**。出厂 `/etc/config/smartdns` 与 `/etc/config/smartdns-lite` 写入了表中大部分键（`cache_size`、`speed_check_mode`、`response_mode`、`prefetch_domain`、`mdns_lookup`、`ui`、`enabled`），未写入的键由 init 兜底值决定，因此未打开页面保存前两者行为略有差异：

| 选项 | 完整版 init 兜底 | 精简版 init 兜底 |
| --- | --- | --- |
| 双栈 IP 优选 | 关（`dualstack-ip-selection no`） | 开 |
| 持久化缓存 | 关（`cache-persist no`） | 开 |

打开页面并保存一次后，两个版本均按上表取值。

默认上游服务器：

| 名称 | 地址 | 类型 | 额外参数 |
| --- | --- | --- | --- |
| Alidns | `h3://dns.alidns.com/dns-query` | h3 | |
| DNSPod | `https://doh.pub/dns-query` | https | |
| Bootstrap DNS | `223.5.5.5` | udp | `-bootstrap-dns` |
| Bootstrap DNS | `119.29.29.29` | udp | `-bootstrap-dns` |

只含域名的上游本身需要先解析域名，因此默认附带两个 `-bootstrap-dns` 的纯 IP 上游用于引导。
完整版把四条记录写成 `config server`；精简版把前两条写成 `list servers`，两条 Bootstrap 使用带选项的 `udp://<ip> -bootstrap-dns` 形式，由精简版 init 原样拼接为 `server` 行。

## 关于 luci-app-smartdns-lite

`luci-app-smartdns-lite` 是面向“只做国内分流 / 分流域名”场景的精简配置页面，与 `luci-app-smartdns` 共用同一个 `smartdns` 服务端（本包不包含守护进程）。

它把页面中的设置生成为 `/var/etc/smartdns/smartdns-lite.conf`，通过 UCI 登记到 `smartdns.@smartdns[0].conf_files`，并按所选模式调整 `enabled`、`port`、`auto_set_dnsmasq`，最后重载 `/etc/init.d/smartdns`。三种模式的行为：

| 模式 | 监听端口 | 对 dnsmasq 的处理 |
| --- | --- | --- |
| Main DNS Server | 53 | 接管：dnsmasq 关闭 DNS（`port=0`），并通过 DHCP option 6 把网关地址下发给客户端 |
| Upstream DNS Server | 自定义（默认 6053） | 不修改 dnsmasq，适合客户端手动指向该端口 |
| Dnsmasq Upstream Server | 自定义（默认 6053） | 把 dnsmasq 的上游指向 `127.0.0.1:<端口>` |

使用要点：

- 必须先安装 `smartdns` 服务端包（本包依赖已声明）；页面状态栏展示的是 `smartdns` 服务的运行状态。
- `Main DNS Server` 模式依赖 `network.lan.ipaddr`；取不到 LAN 地址时不会接管 dnsmasq，smartdns 会因 53 端口被占用而启动失败，此时请改用其余两种模式或手动释放 53 端口。
- 关闭本页面中的 `enabled` 后，会撤销自身生成的配置片段、恢复 dnsmasq 并重载服务。
- 基础设置页提供测速模式、响应模式、双栈 IP 优选、域名预加载、缓存过期服务、缓存大小、持久化缓存、缓存文件、解析本地主机名、mDNS 查询、强制 AAAA/HTTPS SOA、域名 TTL（含最小/最大值）等解析与缓存选项，语义与默认值均与完整版一致。
- 安装 `smartdns-ui` 后，基础设置页会显示 WebUI 选项（启用、端口、数据库目录、日志保存天数）；启用后 `plugin smartdns_ui.so`、`data-dir` 等指令写入本页面的配置片段，运行状态右侧同时出现“打开 WebUI”按钮。默认数据目录为 `/var/lib/smartdns-lite`，避免与完整版的数据库互相影响。
- 两个页面共用 `smartdns` 服务端与 `/etc/smartdns/custom.conf`（自定义配置页），缓存文件也默认位于 `/etc/smartdns/`；同一时刻只应启用其中一个页面，否则会重复接管 dnsmasq 或争抢端口。
- `/etc/init.d/smartdns-lite stop` 只停止服务，不会撤销已登记的 `conf_files`；如需完全停用，请关闭 `enabled` 并保存。

## 兼容性（LuCI 24.10 / 25.12 / main）

- **页面实现**：两个 LuCI 页面都是服务端 ucode 控制器，源码位于 `luci-app-smartdns/ucode/` 与 `luci-app-smartdns-lite/ucode/`（模块 `luci.model.smartdns.*`、`luci.model.smartdns_lite.*` 与 `luci.controller.smartdns`、`luci.controller.smartdns-lite`），由 `luci.mk` 安装到 `/usr/share/ucode/luci`；`htdocs/luci-static/resources/view` 下的客户端 JS 视图已删除，页面不再在浏览器端运行 CBI。
- **LuCI 接口**：已对照 `openwrt/luci` 的 `openwrt-24.10`、`openwrt-25.12` 与 `master` 三个分支确认：菜单动作 `type: "function"`、`require()` 加载 `luci.controller.*`、`ctx.authtoken` 表单令牌校验、`uci`/`ubus`/`fs`/`http` 模块，以及 `luci.mk` 的 `UCODE_LIBRARYDIR` 安装规则与 `Build/Prepare` 目录列表在三个分支中行为一致；所需 `ucode`、`ucode-mod-fs`、`ucode-mod-uci`、`ucode-mod-ubus` 由 `luci-base` 的依赖提供。
- **表单与提交流程**：每个表单都带隐藏的 `token` 字段并由服务端再次校验；保存时通过 `uci` 提交配置并调用 `/etc/init.d/<服务> reload`，重启服务、更新数据文件为独立按钮。
- **Shell**：两个 init 脚本均为 POSIX sh（busybox ash），无 bash 语法；依赖 `iptables`/`ip6tables`，精简版的 TPROXY 规则在存在 `nft` 时优先使用 nftables，`ipset` 仅在使用 ipset 规则时需要；下载列表功能依赖 `wget`（HTTPS 链接需带 libustream 的 busybox wget 或 wget-ssl）。
- **构建**：`rules.mk` 强制使用 bash，Makefile 中的花括号展开安全；完整版 init 以 `INSTALL_BIN` 安装，精简版 init 通过 `PKG_FILE_MODES` 指定权限，均为 0755，不依赖仓库检出时的文件权限位。

## 安装与启用

从源码编译固件时，`rootfs.mk` 会自动执行 `rc.common <init> enable`，无需额外操作。
通过 `opkg` 安装 `.ipk` 时（本仓库不再提供 postinst/prerm），需要手动启用：

```sh
/etc/init.d/smartdns enable
/etc/init.d/smartdns-lite enable   # 使用精简版页面时
```

升级时直接 `opkg upgrade smartdns luci-app-smartdns luci-app-smartdns-lite` 即可；`/etc/config/smartdns`、`/etc/config/smartdns-lite` 与 `/etc/smartdns/*` 已注册为 conffile，会保留用户修改。

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
# 在 OpenWrt 源码树中（24.10 / 25.12 / main 使用本 ucode 分支）
ln -s /path/to/smartdns-openwrt/smartdns feeds/package/smartdns
ln -s /path/to/smartdns-openwrt/luci-app-smartdns feeds/luci/applications/luci-app-smartdns
ln -s /path/to/smartdns-openwrt/luci-app-smartdns-lite feeds/luci/applications/luci-app-smartdns-lite

make menuconfig   # Network -> IP Addresses and Names -> smartdns；LuCI -> Applications -> luci-app-smartdns -> Include smartdns-ui
make package/smartdns/compile V=s
make package/luci-app-smartdns/compile V=s
make package/luci-app-smartdns-lite/compile V=s
```

`Include WebUI` 默认关闭：只装服务端时无需额外操作；需要 Web 面板时，请在选择 `luci-app-smartdns` 后勾选该子选项，或直接选中 `smartdns-ui`（两者等价），否则 `smartdns-ui` 不会被编译进固件。
