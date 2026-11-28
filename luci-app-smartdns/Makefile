#
# Copyright 2018-2025 Nick Peng <pymumu@gmail.com>
# Licensed to the public under the GPL V3 License.

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-smartdns
PKG_VERSION:=1.2025.47.2
PKG_RELEASE:=5

PKG_LICENSE:=GPL-3.0-or-later
PKG_MAINTAINER:=Nick Peng <pymumu@gmail.com>
LUCI_PKGARCH:=all

LUCI_TITLE:=LuCI for smartdns
LUCI_DESCRIPTION:=Provides Luci for smartdns
LUCI_DEPENDS:=+smartdns \
	+PACKAGE_$(PKG_NAME)_INCLUDE_WebUI:smartdns-ui

# The UCI config and the init script belong to this app (the smartdns package
# only ships the binaries), so the full and lite apps do not share them.
PKG_FILE_MODES:=/etc/init.d/smartdns:root:root:0755

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/config
config PACKAGE_$(PKG_NAME)_INCLUDE_WebUI
	bool "Include WebUI support"
	default n
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/smartdns
/etc/smartdns/address.conf
/etc/smartdns/blacklist-ip.conf
/etc/smartdns/domain-block.list
/etc/smartdns/domain-forwarding.list
/etc/smartdns/smartdns.conf
/etc/smartdns/custom.conf
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	mkdir -p /etc/smartdns/conf.d /etc/smartdns/data /etc/smartdns/domain-set /etc/smartdns/ip-set /etc/smartdns/download
	/etc/init.d/smartdns enable
	if [ "$$(uci -q get smartdns.@smartdns[0].enabled)" = "1" ]; then
		/etc/init.d/smartdns restart
	fi
	rm -f /tmp/luci-indexcache.*
	rm -rf /tmp/luci-modulecache/
	/etc/init.d/rpcd reload 2>/dev/null
}
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/smartdns stop
	/etc/init.d/smartdns disable
}
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
