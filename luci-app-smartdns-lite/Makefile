#
# Copyright 2018-2025 Nick Peng <pymumu@gmail.com>
# Licensed to the public under the GPL V3 License.

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-smartdns-lite
PKG_VERSION:=1.2025.47.2
PKG_RELEASE:=2

PKG_LICENSE:=GPL-3.0-or-later
PKG_MAINTAINER:=Nick Peng <pymumu@gmail.com>
LUCI_PKGARCH:=all

LUCI_TITLE:=LuCI for smartdns-lite
LUCI_DESCRIPTION:=Provides a lite LuCI configuration for smartdns
LUCI_DEPENDS:=+smartdns \
	+PACKAGE_$(PKG_NAME)_INCLUDE_WebUI:smartdns-ui

# luci.mk copies root/ verbatim, so force the init script to be executable.
PKG_FILE_MODES:=/etc/init.d/smartdns-lite:root:root:0755

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/config
config PACKAGE_$(PKG_NAME)_INCLUDE_WebUI
	bool "Include WebUI support"
	default n
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/smartdns-lite
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
