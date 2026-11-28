#!/bin/sh
#
# Copyright (C) 2018-2025 Ruilin Peng (Nick) <pymumu@gmail.com>.
#
# smartdns is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# smartdns is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Helpers shared by /etc/init.d/smartdns and /etc/init.d/smartdns-lite:
# config fragment writing and the dnsmasq takeover/restore logic.

DNSMASQ_RESTART="0"

conf_append()
{
	if [ "$#" -gt 1 ] && [ -n "$2" ]; then
		echo "$1 $2" >> "$SMARTDNS_CONF_TMP"
	else
		echo "$1" >> "$SMARTDNS_CONF_TMP"
	fi
}

client_rule_addr_append()
{
	conf_append "client-rules" "$1"
}

# Restart dnsmasq now, or remember it and let restart_pending_dnsmasq()
# do a single restart after several uci changes.
restart_dnsmasq()
{
	local defer="$1"

	if [ "$defer" = "1" ]; then
		DNSMASQ_RESTART="1"
		return 0
	fi

	DNSMASQ_RESTART="0"
	/etc/init.d/dnsmasq restart
}

restart_pending_dnsmasq()
{
	[ "$DNSMASQ_RESTART" = "1" ] || return 0
	DNSMASQ_RESTART="0"
	/etc/init.d/dnsmasq restart
}

set_forward_dnsmasq()
{
	local port="$1"
	local defer="$2"
	local addr="127.0.0.1#${port}"
	local old_server

	# The trailing space makes it possible to match whole list entries.
	old_server="$(uci -q get dhcp.@dnsmasq[0].server) "
	case "$old_server" in
	*"$addr "*) return 0 ;;
	esac

	uci -q delete dhcp.@dnsmasq[0].server
	uci -q add_list dhcp.@dnsmasq[0].server="$addr"
	uci -q set dhcp.@dnsmasq[0].noresolv="1"
	uci -q set dhcp.@dnsmasq[0].rebind_protection="0"
	uci -q set dhcp.@dnsmasq[0].domainneeded="0"
	uci commit dhcp
	restart_dnsmasq "$defer"
}

stop_forward_dnsmasq()
{
	local port="$1"
	local norestart="$2"
	local defer="$3"
	local addr="127.0.0.1#${port}"
	local old_server

	old_server="$(uci -q get dhcp.@dnsmasq[0].server) "
	case "$old_server" in
	*"$addr "*) ;;
	*) return 0 ;;
	esac

	uci -q delete dhcp.@dnsmasq[0].server
	uci -q delete dhcp.@dnsmasq[0].noresolv
	uci -q set dhcp.@dnsmasq[0].rebind_protection="1"
	uci -q set dhcp.@dnsmasq[0].domainneeded="1"
	uci commit dhcp
	[ "$norestart" = "1" ] || restart_dnsmasq "$defer"
}

set_main_dns()
{
	local defer="$1"
	local hostip dnsmasq_port redir_dns uci_batch

	hostip="$(uci -q get network.lan.ipaddr | sed 's/\/.*//g')"
	[ -z "$hostip" ] && return 0

	dnsmasq_port="$(uci -q get dhcp.@dnsmasq[0].port)"
	[ -z "$dnsmasq_port" ] && dnsmasq_port="53"

	uci_batch=""
	if [ "$dnsmasq_port" = "53" ]; then
		uci_batch="${uci_batch}set dhcp.@dnsmasq[0].port=0\n"
		# add_list is not idempotent, guard against duplicate options.
		if ! uci -q get dhcp.lan.dhcp_option 2>/dev/null | tr ' ' '\n' | grep -Fqx "6,$hostip"; then
			uci_batch="${uci_batch}add_list dhcp.lan.dhcp_option=\"6,$hostip\"\n"
		fi
	fi

	# For some third-party firmware.
	redir_dns="$(uci -q get dhcp.@dnsmasq[0].dns_redirect)"
	if [ "$redir_dns" = "1" ]; then
		uci_batch="${uci_batch}set dhcp.@dnsmasq[0].dns_redirect=0\n"
		uci_batch="${uci_batch}set dhcp.@dnsmasq[0].old_dns_redirect=1\n"
	fi

	[ -z "$uci_batch" ] && return 0

	printf '%b' "$uci_batch" | uci batch -q -
	uci commit dhcp
	restart_dnsmasq "$defer"
}

stop_main_dns()
{
	local norestart="$1"
	local defer="$2"
	local hostip dnsmasq_port redir_dns uci_batch

	dnsmasq_port="$(uci -q get dhcp.@dnsmasq[0].port)"
	[ "$dnsmasq_port" != "0" ] && return 0

	hostip="$(uci -q get network.lan.ipaddr | sed 's/\/.*//g')"
	redir_dns="$(uci -q get dhcp.@dnsmasq[0].old_dns_redirect)"

	uci_batch=""
	if [ "$redir_dns" = "1" ]; then
		uci_batch="${uci_batch}set dhcp.@dnsmasq[0].dns_redirect=1\n"
		uci_batch="${uci_batch}delete dhcp.@dnsmasq[0].old_dns_redirect\n"
	fi
	uci_batch="${uci_batch}delete dhcp.@dnsmasq[0].port\n"
	[ -n "$hostip" ] && uci_batch="${uci_batch}del_list dhcp.lan.dhcp_option=\"6,$hostip\"\n"

	printf '%b' "$uci_batch" | uci batch -q -
	uci commit dhcp
	[ "$norestart" = "1" ] || restart_dnsmasq "$defer"
}
