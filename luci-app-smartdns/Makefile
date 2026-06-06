#
# Copyright 2018-2025 Nick Peng <pymumu@gmail.com>
# Licensed to the public under the GPL V3 License.

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-smartdns
PKG_VERSION:=1.2025.47.2
PKG_RELEASE:=1

PKG_LICENSE:=GPL-3.0-or-later
PKG_MAINTAINER:=Nick Peng <pymumu@gmail.com>
LUCI_PKGARCH:=all

LUCI_TITLE:=LuCI for smartdns
LUCI_DESCRIPTION:=Provides Luci for smartdns
LUCI_DEPENDS:=+smartdns
LUCI_ACL:=luci-app-smartdns

PKG_CONFIG_DEPENDS:=CONFIG_PACKAGE_luci-app-smartdns_INCLUDE_WebUI

define Package/luci-app-smartdns/config
config PACKAGE_luci-app-smartdns_INCLUDE_WebUI
	bool "Include WebUI support"
endef

# Only choice smartdns-ui(smartdns&WebUI)(:=)
ifdef CONFIG_PACKAGE_luci-app-smartdns_INCLUDE_WebUI
LUCI_DEPENDS:=+smartdns-ui
endif

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature