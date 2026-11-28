# smartdns-openwrt

面向 **OpenWrt 21.02** 分支的 smartdns 打包仓库，包含 smartdns 服务端、Web 面板及 LuCI 应用。
服务端与面板已拆分为两个独立软件包，可分别安装、升级。

## 包结构

| 软件包 | 内容 | 依赖 |
| --- | --- | --- |
| `smartdns` | 主程序 `/usr/sbin/smartdns`（不含 UCI 配置、init 脚本与数据文件） | `libc`、`libpthread`、`zlib`；系统 OpenSSL < 3.3 时加 `smartdns-openssl`，≥ 3.3 时加 `libopenssl` |
| `smartdns-openssl` | OpenSSL 3 运行库：`/usr/lib/smartdns/libssl.so.3`、`libcrypto.so.3`（隐藏包，系统 OpenSSL < 3.3 时安装） | 仅 `aarch64`、`arm`、`x86_64` |
| `WebUI` | Web 面板：`/usr/lib/smartdns_ui.so` 与 `/usr/share/smartdns/wwwroot` | `smartdns` |
| `luci-app-smartdns` | LuCI 配置页面、`/etc/config/smartdns`、`/etc/init.d/smartdns`、`/etc/smartdns` 预设数据文件（`address.conf`、`blacklist-ip.conf`、`domain-block.list`、`domain-forwarding.list`、`smartdns.conf`） | `smartdns`，可选 `WebUI` |
| `luci-app-smartdns-lite` | 精简版 LuCI 配置页面、`/etc/config/smartdns-lite`、`/etc/init.d/smartdns-lite`、`/etc/smartdns-lite` 数据目录（独立的 `smartdns` 实例） | `smartdns` |

UCI 配置、init 脚本与数据目录分别由两个 LuCI 应用携带，互不共用：完整版使用 `/etc/config/smartdns` + `/etc/init.d/smartdns` + `/etc/smartdns`，精简版使用 `/etc/config/smartdns-lite` + `/etc/init.d/smartdns-lite` + `/etc/smartdns-lite`；`smartdns` 包只提供二进制（以及可选的 WebUI、OpenSSL 运行库）。

安装 `luci-app-smartdns` 时，`Include WebUI` 选项（`PACKAGE_luci-app-smartdns_INCLUDE_WebUI`，**默认关闭**）决定是否一并安装面板。
默认只安装 DNS 服务端；需要面板时，在 menuconfig 中勾选该子选项，或在 `.config` 中写入 `CONFIG_PACKAGE_luci-app-smartdns_INCLUDE_WebUI=y`（等价于直接选中 `CONFIG_PACKAGE_smartdns-ui=y`）。
未安装面板时，LuCI 页面不会显示 Web 面板相关设置。
若曾开启 Web 面板后又卸载 `smartdns-ui`，init 脚本会检测到插件缺失并跳过面板配置，不影响 DNS 服务启动。

## 关于 luci-app-smartdns-lite

`luci-app-smartdns-lite` 是面向“只做国内分流 / 分流域名”场景的精简配置页面，与 `luci-app-smartdns` 互不冲突，可同时安装。

它使用 `smartdns` 包中的二进制，但拥有独立的配置、数据目录与实例：页面设置会生成完整的 `/var/etc/smartdns/smartdns-lite.conf`，由 `/etc/init.d/smartdns-lite` 通过 procd 以 `smartdns -f -c` 启动，并只读写自己的 `/etc/smartdns-lite`（`custom.conf`、`domain-set/`、`ip-set/`），不读写 `smartdns` 的 UCI 配置，也不调用 `/etc/init.d/smartdns`。因此：

- 必须先安装 `smartdns` 服务端包（本包依赖已声明），但无需启用 `smartdns` 服务；
- 页面状态栏展示的是 `smartdns-lite` 实例的运行状态；
- `Main DNS` 模式会接管 dnsmasq（关闭 dnsmasq 的 53 端口并下发 DHCP DNS），`Dnsmasq Upstream` 模式则把 dnsmasq 的上游指向本实例；
- 关闭 `enabled` 或停止服务时，会撤销对 dnsmasq 的修改并清理 TPROXY 规则；
- 基础设置页还提供测速模式、响应模式、双栈 IP 优选、域名预加载、缓存过期服务、缓存大小、持久化缓存/缓存文件、解析本地主机名、mDNS 查询、Force AAAA/HTTPS SOA 与域名 TTL，生成逻辑与默认值均与完整版对应选项一致；
- 安装 `smartdns-ui`（WebUI）后，可在基础设置页启用 WebUI 并设置端口、数据库目录与日志保存天数，生成的 `plugin smartdns_ui.so` 等指令由 `smartdns-lite` 实例加载，运行状态旁会显示“打开 WebUI”按钮。

## 默认配置

两个应用首次生成配置时采用相同的默认值：

- 测速模式：`tcp-syn:443,tcp-syn:80,ping`
- 响应模式：`first-ping`（最快 Ping）
- 域名预加载、缓存过期服务、持久化缓存、解析本地主机名、mDNS 查询：开启
- 缓存大小：`8000`
- 双栈 IP 优选：开启；Force HTTPS SOA：开启；Force AAAA SOA：关闭
- 默认上游服务器（完整版为 4 个 server 段；精简版中 Alidns/DNSPod 写入 `servers` 列表，两条 Bootstrap 写入 `/etc/smartdns-lite/custom.conf`，因为 smartdns 的 UDP 服务器只接受纯 IP 写法，无法通过页面“必须带协议前缀”的校验）：
  1. Alidns：`h3://dns.alidns.com/dns-query`（h3）
  2. DNSPod：`https://doh.pub/dns-query`（https）
  3. Bootstrap DNS：`223.5.5.5`（udp，附加参数 `-bootstrap-dns`）
  4. Bootstrap DNS：`119.29.29.29`（udp，附加参数 `-bootstrap-dns`）

完整版在 `/etc/config/smartdns` 中以 `config server` 段提供；精简版在 `/etc/config/smartdns-lite` 中以 `list servers` 提供，服务器地址后可跟 `-bootstrap-dns` 等 smartdns 服务器参数。

## 为什么使用预构建二进制

本仓库直接使用 [PikuZheng/smartdns](https://github.com/PikuZheng/smartdns) 发布的 `smartdns_with_ui` 预构建包，其中已包含 **OpenSSL 3.5.9 (LTS)** 与 **smartdns-ui**。原因如下：

- **OpenSSL 版本**：OpenWrt 21.02 / 22.03 自带的 OpenSSL 为 1.1.1，缺少 QUIC / HTTP3 所需的 TLS 接口，因此 **不支持 DoQ / DoH3**；预构建包内置 OpenSSL 3.5.9 LTS，从而补齐 DoQ / DoH3 支持。
- **运行库安装策略**：预构建二进制导入了带 `OPENSSL_3.2.0` / `OPENSSL_3.3.0` 版本标记的符号，因此只有系统 OpenSSL ≥ 3.3 时才能直接复用系统库（目前仅 main/SNAPSHOT 的 3.5.x 满足）。21.02（1.1.1）、22.03（1.1.1）、23.05（3.0.19）、24.10（3.0.22）都由隐藏包 `smartdns-openssl` 把两个库安装到 `/usr/lib/smartdns/`。init 脚本启动时设置 `LD_LIBRARY_PATH=/usr/lib/smartdns:/usr/lib:/lib`，因此两种情况都能正确加载。
- **Rust 工具链**：`smartdns-ui` 由 Rust 编写，而 OpenWrt 21.02 的软件源中没有 Rust，无法在 21.02 上现场编译面板，只能使用预构建产物。

只能覆盖官方提供预构建的架构：`aarch64`、`arm`（armv7）、`x86_64`。

## 升级版本

修改 `smartdns/Makefile` 中的 `PKG_VERSION`，并按架构更新 `PKG_HASH`（对应 release 资产 `smartdns_with_ui.1.2026.v<版本>.<架构>.tar.gz`）。
三个软件包共用同一压缩包，版本与哈希只需维护一处。

从旧版本升级时，`/etc/config/smartdns`、`/etc/init.d/smartdns` 以及 `/etc/smartdns` 下全部数据文件（含 `custom.conf`）的所有权从 `smartdns` 迁移到 `luci-app-smartdns`。请先升级 `smartdns`、再升级 `luci-app-smartdns`（`opkg upgrade smartdns luci-app-smartdns` 即按此顺序执行），否则旧版 `smartdns` 仍占用这些文件，opkg 会报文件冲突。已有配置文件会保留。

精简版此前也使用 `/etc/smartdns`，升级后改为独立的 `/etc/smartdns-lite`；旧目录中的 `custom.conf` 内容与上传文件不会自动迁移（该目录现归完整版所有），如需保留请手动复制到 `/etc/smartdns-lite/`。

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
