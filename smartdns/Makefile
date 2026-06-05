# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (c) 2018-2025 Ruilin Peng (Nick) <pymumu@gmail.com>
# Copyright (C) 2021 ImmortalWrt.org
# Modified for prebuilt ipk on OpenWrt 21.02

include $(TOPDIR)/rules.mk

PKG_NAME:=smartdns
PKG_VERSION:=48.0.14
PKG_RELEASE:=1

ifeq ($(ARCH),aarch64)
  PKG_ARCH:=aarch64
  PKG_HASH:=73c435d0e92436a9099e475264cb8f27ec9237c54bf47cfc30bf9b4f05e99315
else ifeq ($(ARCH),x86_64)
  PKG_ARCH:=x86_64
  PKG_HASH:=c33f2b778a61e546ef79d747c77316217144cd5ce0fddc3c1d8ef97d0bd59e16
else ifeq ($(filter arm%,$(ARCH)),)
  PKG_ARCH:=armv7
  PKG_HASH:=3f5ed64b62ac13d96a3fc757c49609e7484203aca8802acc7a09512f2c320454
else
  $(error Unsupported architecture: $(ARCH). PikuZheng prebuilt ipk only provides aarch64, armv7, x86_64)
endif

PKG_SOURCE:=smartdns_with_ui.1.2026.v$(PKG_VERSION).$(PKG_ARCH).tar.gz
PKG_SOURCE_URL:=https://github.com/PikuZheng/smartdns/releases/download/1.2026.v$(PKG_VERSION)_with_ui/

PKG_MAINTAINER:=Nick Peng <pymumu@gmail.com>
PKG_LICENSE:=GPL-3.0-or-later
PKG_LICENSE_FILES:=LICENSE

ifeq ($(ARCH),aarch64)
  PKG_ARCH:=aarch64
else ifeq ($(ARCH),x86_64)
  PKG_ARCH:=x86_64
else ifeq ($(filter arm%,$(ARCH)),)
  PKG_ARCH:=armv7
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
  DEPENDS:=@(aarch64||arm||x86_64)
endef

define Package/smartdns
  $(call Package/smartdns/Default)
  TITLE+= server
  DEPENDS:=+libc +libpthread +libz
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

TAR_CMD:=$(HOST_TAR) -C $(PKG_BUILD_DIR) $(TAR_OPTIONS)

define Build/Compile
endef

define Package/smartdns/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/tmp/smartdns-openwrt/root/usr/sbin/smartdns $(1)/usr/sbin/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(CURDIR)/etc/init.d/smartdns $(1)/etc/init.d/
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) $(CURDIR)/etc/config/smartdns $(1)/etc/config/
	$(INSTALL_DIR) $(1)/etc/smartdns
	$(INSTALL_DIR) $(1)/etc/smartdns/{conf.d,data,domain-set,ip-set,download}
	$(INSTALL_CONF) $(CURDIR)/etc/smartdns/*.conf $(1)/etc/smartdns/
	$(INSTALL_CONF) $(CURDIR)/etc/smartdns/*.list $(1)/etc/smartdns/
	$(INSTALL_DIR) $(1)/usr/lib/smartdns
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/tmp/smartdns-openwrt/root/usr/lib/smartdns/libcrypto.so.3 $(1)/usr/lib/smartdns/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/tmp/smartdns-openwrt/root/usr/lib/smartdns/libssl.so.3 $(1)/usr/lib/smartdns/
endef

define Package/smartdns-ui/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/tmp/smartdns-openwrt/root/usr/lib/smartdns_ui.so $(1)/usr/lib/
	$(INSTALL_DIR) $(1)/usr/share/smartdns
	$(CP) $(PKG_BUILD_DIR)/tmp/smartdns-openwrt/root/usr/share/smartdns/wwwroot $(1)/usr/share/smartdns/
endef

$(eval $(call BuildPackage,smartdns))
$(eval $(call BuildPackage,smartdns-ui))