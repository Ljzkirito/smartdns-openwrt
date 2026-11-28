# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (c) 2018-2025 Ruilin Peng (Nick) <pymumu@gmail.com>
# Copyright (C) 2021 ImmortalWrt.org
# Modified for prebuilt tar.gz on OpenWrt 21.02

include $(TOPDIR)/rules.mk

PKG_NAME:=smartdns
PKG_VERSION:=48.5.4
PKG_RELEASE:=3

ifeq ($(ARCH),aarch64)
  PKG_ARCH:=aarch64
  PKG_HASH:=39a893bbf081c7916b9c45504ff3c64fe89fd3e3086801f1f9d0c93fc94b468e
else ifeq ($(ARCH),x86_64)
  PKG_ARCH:=x86_64
  PKG_HASH:=89f3a0378cf4e5588acf4a967ce887180ee8dfe01ee0138d5aa2ca9ea02ddf51
else ifeq ($(ARCH),arm)
  PKG_ARCH:=armv7
  PKG_HASH:=0509a8e8ddd2567faa8a402e0381aa399224183629d62f5d789efc4035acab7a
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

# The prebuilt binary imports OPENSSL_3.2.0 / OPENSSL_3.3.0 versioned symbols,
# so it can only use the system OpenSSL when that is >= 3.3 (currently the
# main/SNAPSHOT tree ships 3.5.x). 23.05 (3.0.19) and 24.10 (3.0.22) still
# provide OpenSSL 3.0, therefore they keep the bundled runtime libraries.
SMARTDNS_SYSTEM_OPENSSL:=$(shell sed -n 's/^PKG_VERSION:=\([0-9][0-9.]*\).*/\1/p' $(TOPDIR)/package/libs/openssl/Makefile 2>/dev/null | head -n1)
SMARTDNS_OPENSSL_MAJOR:=$(word 1,$(subst ., ,$(SMARTDNS_SYSTEM_OPENSSL)))
SMARTDNS_OPENSSL_MINOR:=$(word 2,$(subst ., ,$(SMARTDNS_SYSTEM_OPENSSL)))
SMARTDNS_USE_SYSTEM_OPENSSL:=$(shell [ "$(SMARTDNS_OPENSSL_MAJOR)" = 3 ] && [ "$(SMARTDNS_OPENSSL_MINOR)" -ge 3 ] 2>/dev/null && echo 1)
ifeq ($(SMARTDNS_USE_SYSTEM_OPENSSL),1)
  SMARTDNS_OPENSSL_DEP:=+libopenssl
else
  SMARTDNS_OPENSSL_DEP:=+smartdns-openssl
endif

define Package/smartdns
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=IP Addresses and Names
  URL:=https://www.github.com/pymumu/smartdns/
  TITLE:=smartdns server
  DEPENDS:=@(aarch64||arm||x86_64) +libc +libpthread +zlib $(SMARTDNS_OPENSSL_DEP)
endef

define Package/smartdns/description
SmartDNS is a local DNS server which accepts DNS query requests from local network clients,
gets DNS query results from multiple upstream DNS servers concurrently, and returns the fastest IP to clients.
Unlike dnsmasq's all-servers, smartdns returns the fastest IP, and encrypt DNS queries with DoT or DoH. 
endef

define Package/smartdns/conffiles
/etc/config/smartdns
/etc/smartdns/address.conf
/etc/smartdns/blacklist-ip.conf
/etc/smartdns/custom.conf
/etc/smartdns/domain-block.list
/etc/smartdns/domain-forwarding.list
/etc/smartdns/smartdns.conf
endef

define Package/smartdns-ui
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=IP Addresses and Names
  URL:=https://www.github.com/pymumu/smartdns/
  TITLE:=smartdns dashboard
  DEPENDS:=@(aarch64||arm||x86_64) +smartdns
endef

define Package/smartdns-ui/description
A dashboard ui for smartdns server.
endef

define Package/smartdns-openssl
  SECTION:=libs
  CATEGORY:=Libraries
  URL:=https://www.github.com/pymumu/smartdns/
  TITLE:=Bundled OpenSSL 3 runtime for smartdns
  DEPENDS:=@(aarch64||arm||x86_64)
  HIDDEN:=1
endef

define Package/smartdns-openssl/description
Bundled libssl/libcrypto of OpenSSL 3 for the prebuilt smartdns binary.
Installed when the system OpenSSL is older than 3.3.
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
endef

define Package/smartdns-openssl/install
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
$(eval $(call BuildPackage,smartdns-openssl))
