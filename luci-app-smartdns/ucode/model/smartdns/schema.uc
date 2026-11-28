// SPDX-License-Identifier: GPL-3.0-or-later
// Schema of the SmartDNS LuCI application (luci-app-smartdns).
// Rendered by luci.model.smartdns.form.

import { stat } from 'fs';

function field(name, title, type, extra) {
	let out = { name: name, title: title, type: type ?? 'text' };

	for (let k, v in (extra ?? {}))
		out[k] = v;

	return out;
}

function flag(name, title, description, extra) {
	let out = { description: description };

	for (let k, v in (extra ?? {}))
		out[k] = v;

	return field(name, title, 'flag', out);
}

function text(name, title, description, extra) {
	let out = { description: description };

	for (let k, v in (extra ?? {}))
		out[k] = v;

	return field(name, title, 'text', out);
}

function num(name, title, description, extra) {
	let out = { description: description };

	for (let k, v in (extra ?? {}))
		out[k] = v;

	return field(name, title, 'number', out);
}

function select(name, title, values, description, extra) {
	let out = { description: description, values: values };

	for (let k, v in (extra ?? {}))
		out[k] = v;

	return field(name, title, 'select', out);
}

function list_of(name, title, description, extra) {
	let out = { description: description };

	for (let k, v in (extra ?? {}))
		out[k] = v;

	return field(name, title, 'list', out);
}

function depends(when_field, when_value) {
	return [ { field: when_field, value: when_value } ];
}

function hour_options() {
	let out = [];

	for (let h = 0; h < 24; h++)
		push(out, [ sprintf('%d', h), sprintf('%02d:00', h) ]);

	return out;
}

function weekday_options() {
	return [
		[ '0', 'Sunday' ],
		[ '1', 'Monday' ],
		[ '2', 'Tuesday' ],
		[ '3', 'Wednesday' ],
		[ '4', 'Thursday' ],
		[ '5', 'Friday' ],
		[ '6', 'Saturday' ]
	];
}

let log_levels = [
	[ 'default', 'Default' ],
	[ 'debug', 'Debug' ],
	[ 'info', 'Info' ],
	[ 'notice', 'Notice' ],
	[ 'warn', 'Warning' ],
	[ 'error', 'Error' ],
	[ 'fatal', 'Fatal' ],
	[ 'off', 'Disabled' ]
];

let log_output_modes = [
	[ 'file', 'File' ],
	[ 'syslog', 'Syslog' ]
];

let server_types = [
	[ 'udp', 'udp' ],
	[ 'tcp', 'tcp' ],
	[ 'tls', 'tls' ],
	[ 'https', 'https' ],
	[ 'quic', 'quic' ],
	[ 'h3', 'h3' ]
];

let download_types = [
	[ 'list', 'Domain List' ],
	[ 'config', 'Configuration' ],
	[ 'ip-set', 'IP Set' ],
	[ 'other', 'Other' ]
];

function to_list(v) {
	if (v == null)
		return [];

	return type(v) == 'array' ? v : [ v ];
}

function dnsmasq_forwarded(db, port) {
	db.load('dhcp');

	let sid = db.get_first('dhcp', 'dnsmasq');

	if (sid == null)
		return true;

	let section = db.get_all('dhcp', sid);

	if (section == null)
		return true;

	let needle = '127.0.0.1#' + port;

	for (let entry in to_list(section.server)) {
		if (entry + '' == needle)
			return true;
	}

	return false;
}

function status(env, db) {
	let running = false;
	let warnings = [];

	try {
		let res = env.ubus.call('service', 'list', { name: 'smartdns' });
		let service = res != null ? res.smartdns : null;

		if (service != null && service.instances != null) {
			for (let iname, instance in service.instances) {
				if (instance != null && instance.running === true)
					running = true;
			}
		}
	}
	catch (e) {
		running = false;
	}

	let enabled = db.get('smartdns', 'smartdns', 'enabled');
	let port = db.get('smartdns', 'smartdns', 'port') ?? '53';
	let auto_set = db.get('smartdns', 'smartdns', 'auto_set_dnsmasq');
	let ui = db.get('smartdns', 'smartdns', 'ui');

	if (!running && enabled == '1')
		push(warnings, 'SmartDNS is enabled but not running. Please check the system log and whether the configuration is valid.');

	if (auto_set == '1' && port != '53' && !dnsmasq_forwarded(db, port))
		push(warnings, 'Dnsmasq Forwarded To Smartdns Failure');

	let webui = null;

	if (ui == '1' && stat('/usr/lib/smartdns_ui.so') != null) {
		let host = env.http.getenv('SERVER_NAME') ?? 'localhost';
		let ui_port = db.get('smartdns', 'smartdns', 'ui_port') ?? '6080';

		webui = '//' + host + ':' + ui_port;
	}

	return { running: running, warnings: warnings, webui: webui };
}

let settings = [
	flag('enabled', 'Enable', 'Enable or disable smartdns server'),
	text('server_name', 'DNS Server Name', 'Host name reported to clients'),
	num('port', 'DNS Server port', 'Port the DNS server listens on', { datatype: 'port' }),
	flag('auto_set_dnsmasq', 'Automatically set dnsmasq', 'Forward dnsmasq queries to SmartDNS'),
	flag('ui', 'Enable WebUI', 'Enable the SmartDNS WebUI if it is installed'),
	num('ui_port', 'WebUI port', 'Listening port of the WebUI', { datatype: 'port', depends: depends('ui', '1') }),
	text('ui_data_dir', 'WebUI data directory', 'Directory used to store WebUI data', { depends: depends('ui', '1') }),
	num('ui_log_max_age', 'WebUI log max age', 'Maximum age of stored WebUI logs in days', { datatype: 'uinteger', depends: depends('ui', '1') })
];

let advanced = [
	text('speed_check_mode', 'Speed Check Mode', 'Comma separated list, e.g. tcp-syn:443,tcp-syn:80,ping', {
		suggest: [ 'tcp-syn:443', 'tcp-syn:80', 'ping' ],
		check: function(v) {
			for (let item in split(v, ',')) {
				item = trim(item);

				if (!length(item))
					continue;

				if (item == 'ping')
					continue;

				if (substr(item, 0, 4) == 'tcp:' || substr(item, 0, 8) == 'tcp-syn:')
					continue;

				return false;
			}

			return true;
		}
	}),
	select('response_mode', 'Response Mode', [
		[ 'first-ping', 'First Ping' ],
		[ 'fastest-ip', 'Fastest IP' ],
		[ 'fastest-response', 'Fastest Response' ]
	]),
	flag('tcp_server', 'Enable TCP Server', 'Accept plain TCP queries'),
	flag('tls_server', 'Enable TLS Server', 'Accept DNS over TLS queries'),
	num('tls_server_port', 'TLS Server Port', 'Listening port of the TLS server', { datatype: 'port', depends: depends('tls_server', '1') }),
	flag('doh_server', 'Enable DoH Server', 'Accept DNS over HTTPS queries'),
	num('doh_server_port', 'DoH Server Port', 'Listening port of the DoH server', { datatype: 'port', depends: depends('doh_server', '1') }),
	flag('ddr', 'Enable DDR', 'Discover designated resolvers automatically'),
	text('bind_cert', 'Certificate File', 'Path of the TLS certificate'),
	text('bind_cert_key', 'Certificate Key File', 'Path of the TLS certificate key'),
	field('bind_cert_key_pass', 'Certificate Key Password', 'password', { description: 'Password of the TLS certificate key' }),
	select('bind_cert_generate', 'Generate Certificate', [
		[ 'auto', 'Automatic' ],
		[ 'yes', 'Yes' ],
		[ 'no', 'No' ]
	]),
	text('bind_cert_san', 'Certificate Subject Alternative Name', 'Additional SAN entries of the generated certificate'),
	text('bind_cert_root_key', 'Certificate Root Key File', 'Path of the root key used to sign generated certificates'),
	flag('ipv6_server', 'Enable IPv6 Server', 'Listen on IPv6 addresses'),
	text('bind_device', 'Bind Device', 'Comma separated list of network devices to bind to'),
	flag('bind_device_name', 'Bind Device Name', 'Use the device name instead of the device index'),
	flag('dualstack_ip_selection', 'Dual-stack IP Selection', 'Select the fastest IPv4 or IPv6 address'),
	flag('prefetch_domain', 'Domain prefetch', 'Prefetch expired domain records in advance'),
	flag('serve_expired', 'Serve expired', 'Serve expired cache entries while refreshing'),
	num('cache_size', 'Cache Size', 'Number of cached domain records', { datatype: 'uinteger' }),
	flag('cache_persist', 'Cache Persist', 'Persist the cache across restarts'),
	text('cache_file', 'Cache File', 'Path of the persistent cache file'),
	flag('resolve_local_hostnames', 'Resolve local hostnames', 'Resolve hostnames from /etc/hosts and DHCP leases'),
	flag('mdns_lookup', 'Enable mDNS lookup', 'Resolve .local hostnames through mDNS'),
	text('ddns_domain', 'DDNS Domain', 'Domain used to detect the public address'),
	text('local_domain', 'Local Domain', 'Local domain suffix'),
	flag('force_aaaa_soa', 'Force AAAA SOA', 'Return SOA for empty AAAA answers'),
	flag('force_https_soa', 'Force HTTPS SOA', 'Return SOA for empty HTTPS answers'),
	text('ipset_name', 'IPset Name', 'IPset collecting resolved addresses', { datatype: 'ipset' }),
	flag('ipset_no_speed', 'IPset No Speed Check', 'Skip the speed check for IPset results'),
	text('nftset_name', 'NFTset Name', 'NFTset collecting resolved addresses', { datatype: 'nftset' }),
	flag('nftset_no_speed', 'NFTset No Speed Check', 'Skip the speed check for NFTset results'),
	num('rr_ttl', 'TTL', 'Fixed TTL for all answers', { datatype: 'uinteger' }),
	num('rr_ttl_min', 'TTL Min', 'Minimum TTL of answers', { datatype: 'uinteger' }),
	num('rr_ttl_max', 'TTL Max', 'Maximum TTL of answers', { datatype: 'uinteger' }),
	num('rr_ttl_reply_max', 'Reply TTL Max', 'Maximum TTL of the reply', { datatype: 'uinteger' }),
	text('server_flags', 'Server Flags', 'Global smartdns flags'),
	list_of('conf_files', 'Configuration Files', 'Additional configuration files, one path per line'),
	list_of('hosts_files', 'Hosts Files', 'Additional hosts files, one path per line')
];

let seconddns = [
	flag('seconddns_enabled', 'Enable second server', 'Start a second DNS server instance'),
	num('seconddns_port', 'Second Server Port', 'Listening port of the second server', { datatype: 'port' }),
	flag('seconddns_tcp_server', 'Enable TCP Server', 'Accept plain TCP queries on the second server'),
	text('seconddns_server_group', 'Server Group', 'Server group used by the second server', { datatype: 'hostname' }),
	flag('seconddns_no_speed_check', 'Disable speed check', 'Do not run the speed check on the second server'),
	flag('seconddns_no_rule_addr', 'Disable address rules', 'Ignore address rules on the second server'),
	flag('seconddns_no_rule_nameserver', 'Disable nameserver rules', 'Ignore nameserver rules on the second server'),
	flag('seconddns_no_rule_ipset', 'Disable IPset rules', 'Ignore IPset rules on the second server'),
	flag('seconddns_no_rule_soa', 'Disable SOA rules', 'Ignore SOA rules on the second server'),
	flag('seconddns_no_dualstack_selection', 'Disable dual-stack selection', 'Do not select between IPv4 and IPv6'),
	flag('seconddns_no_cache', 'Disable cache', 'Do not cache answers on the second server'),
	flag('seconddns_force_aaaa_soa', 'Force AAAA SOA', 'Return SOA for empty AAAA answers'),
	flag('seconddns_force_https_soa', 'Force HTTPS SOA', 'Return SOA for empty HTTPS answers'),
	flag('seconddns_no_ip_alias', 'Disable IP alias', 'Ignore IP alias rules on the second server'),
	text('seconddns_ipset_name', 'IPset Name', 'IPset used by the second server', { datatype: 'ipset' }),
	text('seconddns_nftset_name', 'NFTset Name', 'NFTset used by the second server', { datatype: 'nftset' }),
	text('seconddns_server_flags', 'Server Flags', 'Additional flags of the second server')
];

let dns64 = [
	text('dns64', 'DNS64 Prefix', 'IPv6 prefix used for DNS64, e.g. 64:ff9b::/96', { datatype: 'cidr6', placeholder: '64:ff9b::/96' })
];

let auto_update = [
	flag('enable_auto_update', 'Enable auto update', 'Download the configured files periodically'),
	select('auto_update_week_time', 'Update Week Day', weekday_options(), 'Day of the week of the automatic update', { depends: depends('enable_auto_update', '1') }),
	select('auto_update_day_time', 'Update Hour', hour_options(), 'Hour of the automatic update', { depends: depends('enable_auto_update', '1') })
];

let proxy = [
	text('proxy_server', 'Proxy Server', 'Proxy used to download files, e.g. socks5://127.0.0.1:1080', { datatype: 'url' })
];

let log_fields = [
	flag('coredump', 'Generate Coredump', 'Write a coredump on crashes'),
	select('log_level', 'Log Level', log_levels),
	select('log_output_mode', 'Log Output Mode', log_output_modes),
	text('log_size', 'Log Size', 'Maximum size of a log file, e.g. 64K'),
	num('log_num', 'Log Number', 'Number of rotated log files', { datatype: 'uinteger' }),
	text('log_file', 'Log File', 'Path of the log file'),
	flag('enable_audit_log', 'Enable Audit Log', 'Log every query'),
	select('audit_log_output_mode', 'Audit Log Output Mode', log_output_modes, null, { depends: depends('enable_audit_log', '1') }),
	text('audit_log_size', 'Audit Log Size', 'Maximum size of an audit log file', { depends: depends('enable_audit_log', '1') }),
	num('audit_log_num', 'Audit Log Number', 'Number of rotated audit log files', { datatype: 'uinteger', depends: depends('enable_audit_log', '1') }),
	text('audit_log_file', 'Audit Log File', 'Path of the audit log file', { depends: depends('enable_audit_log', '1') })
];

let server_fields = [
	flag('enabled', 'Enable', 'Enable this server'),
	text('name', 'Server Name', 'Display name of this server'),
	text('ip', 'DNS Server ip', 'Server address, e.g. 8.8.8.8 or tls://dns.example.com', { required: true, datatype: 'server' }),
	num('port', 'DNS Server port', 'Port of the server', { datatype: 'port' }),
	select('type', 'DNS Server type', server_types),
	text('server_group', 'Server Group', 'Group this server belongs to', { datatype: 'hostname' }),
	flag('exclude_default_group', 'Exclude Default Group', 'Do not use this server for the default group'),
	text('blacklist_ip', 'IP Blacklist', 'Comma separated list of addresses to filter out', { datatype: 'iplist' }),
	flag('check_edns', 'Check EDNS', 'Verify EDNS support of this server'),
	flag('tls_host_verify', 'TLS Host Verify', 'Verify the host name of the TLS certificate'),
	flag('no_check_certificate', 'No Check Certificate', 'Accept any TLS certificate'),
	text('host_name', 'TLS SNI name', 'TLS server name indication'),
	text('http_host', 'HTTP Host', 'HTTP host header used for DoH queries'),
	text('spki_pin', 'TLS SPKI Pinning', 'Expected SPKI hash of the TLS certificate'),
	num('set_mark', 'Marking Packets', 'SO_MARK value for outgoing queries', { datatype: 'uinteger' }),
	flag('use_proxy', 'Use Proxy', 'Send queries through the configured proxy'),
	flag('fallback', 'Fallback', 'Use this server as a fallback only'),
	text('addition_arg', 'Additional Server Args', 'Additional arguments passed to the server')
];

let client_fields = [
	flag('enabled', 'Enable', 'Enable this rule'),
	text('name', 'Rule Name', 'Display name of this rule'),
	list_of('client_addr', 'Client Address', 'Client addresses, CIDRs or MAC addresses, one per line'),
	text('client_addr_file', 'Client Address File', 'Path of a file containing client addresses'),
	text('server_group', 'Server Group', 'Server group used for matching clients', { datatype: 'hostname' }),
	text('speed_check_mode', 'Speed Check Mode', 'Speed check mode for matching clients'),
	flag('dualstack_ip_selection', 'Dual-stack IP Selection', 'Select the fastest IPv4 or IPv6 address'),
	flag('force_aaaa_soa', 'Force AAAA SOA', 'Return SOA for empty AAAA answers'),
	flag('force_https_soa', 'Force HTTPS SOA', 'Return SOA for empty HTTPS answers'),
	text('ipset_name', 'IPset Name', 'IPset used for matching clients', { datatype: 'ipset' }),
	text('nftset_name', 'NFTset Name', 'NFTset used for matching clients', { datatype: 'nftset' }),
	list_of('conf_files', 'Configuration Files', 'Additional configuration files, one path per line'),
	text('block_domain_set_file', 'Domain Block List File', 'Path of a domain block list')
];

let domain_fields = [
	flag('enabled', 'Enable', 'Enable this rule'),
	text('name', 'Rule Name', 'Display name of this rule'),
	text('server_group', 'Server Group', 'Server group used for matching domains', { datatype: 'hostname' }),
	text('domain_list_file', 'Domain List File', 'Path of a domain list file'),
	select('block_domain_type', 'Block Domain Type', [
		[ 'none', 'None' ],
		[ 'all', 'All' ],
		[ 'ipv4', 'IPv4' ],
		[ 'ipv6', 'IPv6' ]
	]),
	list_of('conf_files', 'Configuration Files', 'Additional configuration files, one path per line'),
	text('speed_check_mode', 'Speed Check Mode', 'Speed check mode for matching domains'),
	flag('dualstack_ip_selection', 'Dual-stack IP Selection', 'Select the fastest IPv4 or IPv6 address'),
	flag('force_aaaa_soa', 'Force AAAA SOA', 'Return SOA for empty AAAA answers'),
	flag('force_https_soa', 'Force HTTPS SOA', 'Return SOA for empty HTTPS answers'),
	text('ipset_name', 'IPset Name', 'IPset used for matching domains', { datatype: 'ipset' }),
	text('nftset_name', 'NFTset Name', 'NFTset used for matching domains', { datatype: 'nftset' }),
	text('addition_flag', 'Additional Rule Flag', 'Additional smartdns flags for matching domains'),
	text('forwarding_domain_set_file', 'Forwarding Domain Set File', 'Path of a domain forwarding list'),
	text('block_domain_set_file', 'Domain Block List File', 'Path of a domain block list')
];

let ip_rule_fields = [
	flag('enabled', 'Enable', 'Enable this rule'),
	text('name', 'Rule Name', 'Display name of this rule'),
	text('ip_set_file', 'IP Set File', 'Path of an IP set file'),
	list_of('ip_addr', 'IP Address', 'IP addresses or CIDRs, one per line'),
	text('whitelist_ip', 'Whitelist IP', 'Comma separated list of whitelisted addresses'),
	text('blacklist_ip', 'Blacklist IP', 'Comma separated list of blacklisted addresses'),
	text('ignore_ip', 'Ignore IP', 'Comma separated list of ignored addresses'),
	flag('bogus_nxdomain', 'Bogus NXDOMAIN', 'Treat matching addresses as non-existent'),
	list_of('ip_alias', 'IP Alias', 'Addresses returned instead, one per line'),
	text('addition_flag', 'Additional Rule Flag', 'Additional smartdns flags for matching addresses')
];

let download_fields = [
	flag('enabled', 'Enable', 'Download this file'),
	text('name', 'File Name', 'Name of the downloaded file', { required: true }),
	text('url', 'Download URL', 'URL of the file', { required: true, datatype: 'url' }),
	select('type', 'File Type', download_types),
	text('desc', 'Description', 'Description of the file'),
	flag('use_proxy', 'Use Proxy', 'Download this file through the configured proxy')
];

export const app = {
	conf: 'smartdns',
	section: 'smartdns',
	base: 'admin/services/smartdns',
	title: 'SmartDNS',
	describe: 'SmartDNS is a local DNS server which performs speed checks on DNS results and returns the fastest address.',
	service: 'smartdns',
	actions: { restart: true, updatefiles: true },
	status: status,
	tabs: [
		{ id: 'settings', title: 'Settings', blocks: [ { kind: 'fields', fields: settings } ] },
		{ id: 'advanced', title: 'Advanced Settings', blocks: [ { kind: 'fields', fields: advanced } ] },
		{ id: 'seconddns', title: 'Second Server Settings', blocks: [ { kind: 'fields', fields: seconddns } ] },
		{ id: 'dns64', title: 'DNS64 Server Settings', blocks: [ { kind: 'fields', fields: dns64 } ] },
		{
			id: 'files', title: 'Download Files Setting', blocks: [
				{ kind: 'fields', fields: auto_update },
				{ kind: 'upload', name: 'conf', title: 'Upload Config File', dir: '/etc/smartdns/conf.d', description: 'The file is stored under /etc/smartdns/conf.d' },
				{ kind: 'upload', name: 'list', title: 'Upload Domain List File', dir: '/etc/smartdns/domain-set', description: 'The file is stored under /etc/smartdns/domain-set' },
				{ kind: 'upload', name: 'other', title: 'Upload Other File', dir: '/etc/smartdns/download', description: 'The file is stored under /etc/smartdns/download' },
				{ kind: 'grid', type: 'download-file', fields: download_fields, label_field: 'name', add_title: 'Add download file', defaults: { enabled: '1', type: 'list' } }
			]
		},
		{ id: 'proxy', title: 'Proxy Server Settings', blocks: [ { kind: 'fields', fields: proxy } ] },
		{
			id: 'custom', title: 'Custom Settings', blocks: [
				{ kind: 'fields', fields: log_fields },
				{ kind: 'file', name: 'custom', path: '/etc/smartdns/custom.conf', rows: 16, title: 'Custom Configuration', description: 'Contents are written to /etc/smartdns/custom.conf' }
			]
		},
		{ id: 'servers', title: 'DNS Server Settings', blocks: [ { kind: 'grid', type: 'server', fields: server_fields, label_field: 'name', add_title: 'Add DNS server', defaults: { enabled: '1', type: 'udp' } } ] },
		{ id: 'clients', title: 'Client Rules', blocks: [ { kind: 'grid', type: 'client-rule', fields: client_fields, label_field: 'name', add_title: 'Add client rule', defaults: { enabled: '1' } } ] },
		{
			id: 'domains', title: 'Domain Rules', blocks: [
				{ kind: 'grid', type: 'domain-rule', fields: domain_fields, label_field: 'name', add_title: 'Add domain rule', defaults: { enabled: '1', block_domain_type: 'none' } },
				{ kind: 'file', name: 'forwarding', path: '/etc/smartdns/domain-forwarding.list', rows: 10, title: 'Domain Forwarding List', description: 'Domains listed here are forwarded to the configured server group' }
			]
		},
		{
			id: 'domainlist', title: 'Domain List', blocks: [
				{ kind: 'grid', type: 'domain-rule-list', fields: domain_fields, label_field: 'name', add_title: 'Add domain rule', defaults: { enabled: '1', block_domain_type: 'none' } },
				{ kind: 'file', name: 'block', path: '/etc/smartdns/domain-block.list', rows: 12, title: 'Domain Block List', description: 'Domains listed here are blocked' },
				{ kind: 'file', name: 'address', path: '/etc/smartdns/address.conf', rows: 12, title: 'Domain Address', description: 'Contents are written to /etc/smartdns/address.conf' }
			]
		},
		{
			id: 'iprules', title: 'IP Rules', blocks: [
				{ kind: 'grid', type: 'ip-rule', fields: ip_rule_fields, label_field: 'name', add_title: 'Add IP rule', defaults: { enabled: '1' } },
				{ kind: 'file', name: 'blackip', path: '/etc/smartdns/blacklist-ip.conf', rows: 12, title: 'IP Blacklist', description: 'Contents are written to /etc/smartdns/blacklist-ip.conf' }
			]
		},
		{
			id: 'support', title: 'Technical Support', blocks: [
				{
					kind: 'links', title: 'Technical Support', links: [
						{ href: 'https://github.com/pymumu/smartdns', title: 'open website' },
						{ href: 'https://github.com/pymumu/smartdns/issues', title: 'Report bugs' },
						{ href: 'https://pymumu.github.io/smartdns/', title: 'Donate' }
					]
				}
			]
		}
	]
};
