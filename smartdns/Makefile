# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (c) 2018-2025 Ruilin Peng (Nick) <pymumu@gmail.com>
# Copyright (C) 2021 ImmortalWrt.org
# Modified for prebuilt tar.gz on OpenWrt 21.02

include $(TOPDIR)/rules.mk

PKG_NAME:=smartdns
PKG_VERSION:=48.4.0
PKG_RELEASE:=1

ifeq ($(ARCH),aarch64)
  PKG_ARCH:=aarch64
  PKG_HASH:=7e4d236221aa5575fe8d6e0cfddab2c3d7d7e3141f9ddb4feb473225a833be5f
else ifeq ($(ARCH),x86_64)
  PKG_ARCH:=x86_64
  PKG_HASH:=0cb1a587e75860c027d26dbd8ea96b6d82eec5f93fc0fbcce5c8f6cd9fbf434f
else ifeq ($(ARCH),arm)
  PKG_ARCH:=armv7
  PKG_HASH:=83da9eac1695566abdc525afccd8847bc6cf1dedcb4e25883620cba85bfe6d4f
# Set the default value to make OpenWrt Package Checker happy
else
  PKG_SOURCE:=dummy
  PKG_HASH:=dummy
endif

PKG_SOURCE:=smartdns_with_ui.1.2026.v$(PKG_VERSION).$(PKG_ARCH).tar.gz
PKG_SOURCE_URL:=https://github.com/PikuZheng/smartdns/releases/download/1.2026.v$(PKG_VERSION)_with_ui/

PKG_MAINTAINER:=Nick Peng <pymumu@gmail.com>
PKG_LICENSE:=GPL-3.0-or-later
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

TAR_CMD:=$(HOST_TAR) -C $(PKG_BUILD_DIR) $(TAR_OPTIONS)

define Package/smartdns
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=IP Addresses and Names
  URL:=https://www.github.com/pymumu/smartdns/
  TITLE:=smartdns server and dashboard
  DEPENDS:=@(aarch64||arm||x86_64) +libc +libpthread +zlib
endef

define Package/smartdns/description
SmartDNS is a local DNS server which accepts DNS query requests from local network clients,
gets DNS query results from multiple upstream DNS servers concurrently, and returns the fastest IP to clients.
Unlike dnsmasq's all-servers, smartdns returns the fastest IP, and encrypt DNS queries with DoT or DoH. 
A dashboard ui for smartdns server.
endef

define Package/smartdns/conffiles
/etc/config/smartdns
/etc/smartdns/address.conf
/etc/smartdns/blacklist-ip.conf
/etc/smartdns/custom.conf
/etc/smartdns/domain-block.list
/etc/smartdns/domain-forwarding.list
endef

define Build/Compile
endef

define Package/smartdns/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/tmp/smartdns-openwrt/root/usr/sbin/smartdns $(1)/usr/sbin/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(CURDIR)/files/init.d/smartdns $(1)/etc/init.d/
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) $(CURDIR)/files/config/smartdns $(1)/etc/config/
	$(INSTALL_DIR) $(1)/etc/smartdns
	$(INSTALL_DIR) $(1)/etc/smartdns/{conf.d,data,domain-set,ip-set,download}
	$(INSTALL_CONF) $(CURDIR)/files/smartdns/*.conf $(1)/etc/smartdns/
	$(INSTALL_CONF) $(CURDIR)/files/smartdns/*.list $(1)/etc/smartdns/
	$(INSTALL_DIR) $(1)/usr/lib/smartdns
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/tmp/smartdns-openwrt/root/usr/lib/smartdns/libcrypto.so.3 $(1)/usr/lib/smartdns/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/tmp/smartdns-openwrt/root/usr/lib/smartdns/libssl.so.3 $(1)/usr/lib/smartdns/

	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/tmp/smartdns-openwrt/root/usr/lib/smartdns_ui.so $(1)/usr/lib/
	$(INSTALL_DIR) $(1)/usr/share/smartdns
	$(CP) $(PKG_BUILD_DIR)/tmp/smartdns-openwrt/root/usr/share/smartdns/wwwroot $(1)/usr/share/smartdns/
endef

$(eval $(call BuildPackage,smartdns))