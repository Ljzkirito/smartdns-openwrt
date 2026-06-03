# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (c) 2018-2025 Ruilin Peng (Nick) <pymumu@gmail.com>
# Modified for prebuilt ipk on OpenWrt 21.02

include $(TOPDIR)/rules.mk

PKG_NAME:=smartdns
PKG_VERSION:=1.2026.v48.0.12
PKG_RELEASE:=1

# 映射 OpenWrt 的 ARCH 到 ipk 文件名中的架构后缀
ifeq ($(ARCH),aarch64)
  PKG_ARCH:=aarch64
else ifeq ($(ARCH),arm)
  PKG_ARCH:=armv7
else ifeq ($(ARCH),x86_64)
  PKG_ARCH:=x86_64
else
  $(error Unsupported architecture: $(ARCH). PikuZheng prebuilt ipk only provides aarch64, armv7, x86_64)
endif

PKG_SOURCE:=smartdns_with_ui.$(PKG_VERSION).$(PKG_ARCH).ipk
PKG_SOURCE_URL:=https://github.com/PikuZheng/smartdns/releases/download/$(PKG_VERSION)_with_ui/
PKG_HASH:=skip

PKG_MAINTAINER:=Nick Peng <pymumu@gmail.com>
PKG_LICENSE:=GPL-3.0-or-later
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

define Package/smartdns/Default
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=IP Addresses and Names
  TITLE:=smartdns
  URL:=https://www.github.com/pymumu/smartdns/
endef

define Package/smartdns
  $(call Package/smartdns/Default)
  TITLE+= server
  DEPENDS:=+libc +libpthread +libopenssl
endef

define Package/smartdns/description
SmartDNS is a local DNS server which accepts DNS query requests from local clients,
gets DNS query results from multiple upstream DNS servers concurrently,
and returns the fastest IP to clients. Supports DoT, DoH, DoQ, DoH3.
This package uses prebuilt binary with bundled OpenSSL 3 libraries.
endef

define Package/smartdns-ui
  $(call Package/smartdns/Default)
  TITLE+= dashboard
  DEPENDS:=+smartdns
endef

define Package/smartdns-ui/description
A dashboard UI for smartdns server.
endef

define Package/smartdns/conffiles
/etc/config/smartdns
/etc/smartdns/address.conf
/etc/smartdns/blacklist-ip.conf
/etc/smartdns/custom.conf
/etc/smartdns/domain-block.list
/etc/smartdns/domain-forwarding.list
endef

# 解压 ipk 中的 data.tar.gz 到构建目录
define Build/Prepare
	$(eval ipk_file := $(DL_DIR)/$(PKG_SOURCE))
	@if [ ! -f "$(ipk_file)" ]; then \
		echo "Error: Downloaded file not found: $(ipk_file)"; \
		exit 1; \
	fi
	mkdir -p $(PKG_BUILD_DIR)
	cd $(PKG_BUILD_DIR) && \
		ar p $(ipk_file) data.tar.gz | tar -xz
endef

define Package/smartdns/install
	# 主程序与启动脚本
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/usr/sbin/smartdns $(1)/usr/sbin/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/etc/init.d/smartdns $(1)/etc/init.d/

	# UCI 配置
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/etc/config/smartdns $(1)/etc/config/

	# smartdns 配置目录及默认文件
	$(INSTALL_DIR) $(1)/etc/smartdns
	$(INSTALL_CONF) $(PKG_BUILD_DIR)/etc/smartdns/address.conf $(1)/etc/smartdns/
	$(INSTALL_CONF) $(PKG_BUILD_DIR)/etc/smartdns/blacklist-ip.conf $(1)/etc/smartdns/
	$(INSTALL_CONF) $(PKG_BUILD_DIR)/etc/smartdns/custom.conf $(1)/etc/smartdns/
	$(INSTALL_CONF) $(PKG_BUILD_DIR)/etc/smartdns/domain-block.list $(1)/etc/smartdns/
	$(INSTALL_CONF) $(PKG_BUILD_DIR)/etc/smartdns/domain-forwarding.list $(1)/etc/smartdns/

	# 自带的 OpenSSL 3 库（放在私有目录避免污染系统）
	$(INSTALL_DIR) $(1)/usr/lib/smartdns
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/usr/lib/smartdns/libcrypto.so.3 $(1)/usr/lib/smartdns/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/usr/lib/smartdns/libssl.so.3 $(1)/usr/lib/smartdns/
endef

define Package/smartdns-ui/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/usr/lib/smartdns_ui.so $(1)/usr/lib/
	# 创建符号链接，兼容 smartdns 查找路径
	ln -sf /usr/lib/smartdns_ui.so $(1)/usr/lib/libsmartdns_ui.so
	$(INSTALL_DIR) $(1)/usr/lib/smartdns
	ln -sf /usr/lib/smartdns_ui.so $(1)/usr/lib/smartdns/libsmartdns_ui.so

	# Web 前端文件
	$(INSTALL_DIR) $(1)/usr/share/smartdns
	$(CP) $(PKG_BUILD_DIR)/usr/share/smartdns/wwwroot $(1)/usr/share/smartdns/
endef

$(eval $(call BuildPackage,smartdns))
$(eval $(call BuildPackage,smartdns-ui))