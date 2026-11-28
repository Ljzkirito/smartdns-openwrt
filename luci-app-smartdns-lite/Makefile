#
# Copyright 2018-2025 Nick Peng <pymumu@gmail.com>
# Licensed to the public under the GPL V3 License.

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-smartdns-lite
PKG_VERSION:=1.2025.47.2
PKG_RELEASE:=6

PKG_LICENSE:=GPL-3.0-or-later
PKG_MAINTAINER:=Nick Peng <pymumu@gmail.com>
LUCI_PKGARCH:=all

LUCI_TITLE:=LuCI for smartdns-lite
LUCI_DESCRIPTION:=Provides a lite LuCI configuration for smartdns
LUCI_DEPENDS:=+smartdns \
	+PACKAGE_$(PKG_NAME)_INCLUDE_WebUI:smartdns-ui

# Only the UCI config belongs to this app; the init script and the
# /etc/smartdns-lite data files are shipped by the smartdns package.

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/config
config PACKAGE_$(PKG_NAME)_INCLUDE_WebUI
	bool "Include WebUI support"
	default n
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/smartdns-lite
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	# Older versions registered the generated file in the full smartdns
	# configuration. Drop it, otherwise both daemons would bind the same port.
	if uci -q get "smartdns.@smartdns[0].conf_files" | grep -qF "/var/etc/smartdns/smartdns-lite.conf"; then
		uci -q del_list "smartdns.@smartdns[0].conf_files=/var/etc/smartdns/smartdns-lite.conf"
		uci -q set "smartdns.@smartdns[0].enabled=0"
		uci commit smartdns
		[ -x /etc/init.d/smartdns ] && /etc/init.d/smartdns reload
	fi
	[ -x /etc/init.d/smartdns-lite ] && /etc/init.d/smartdns-lite clear_rules
	if [ -x /etc/init.d/smartdns-lite ]; then
		if [ "$$(uci -q get smartdns-lite.@smartdns-lite[0].enabled)" = "1" ]; then
			/etc/init.d/smartdns-lite restart
		fi
		/etc/init.d/smartdns-lite enable
	fi
	rm -f /tmp/luci-indexcache.*
	rm -rf /tmp/luci-modulecache/
	/etc/init.d/rpcd reload 2>/dev/null
}
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	[ -x /etc/init.d/smartdns-lite ] && /etc/init.d/smartdns-lite stop
	[ -x /etc/init.d/smartdns-lite ] && /etc/init.d/smartdns-lite disable
	rm -f /var/etc/smartdns/smartdns-lite.conf
}
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
