// SPDX-License-Identifier: GPL-3.0-or-later
// Schema of the SmartDNS Lite LuCI application (luci-app-smartdns-lite).

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

function check_speed_mode(v) {
	for (let item in split(v, ',')) {
		item = trim(item);

		if (!length(item) || item == 'none' || item == 'ping')
			continue;

		if (substr(item, 0, 4) == 'tcp:') {
			if (!length(substr(item, 4)))
				return false;

			continue;
		}

		if (substr(item, 0, 8) == 'tcp-syn:') {
			if (!length(substr(item, 8)))
				return false;

			continue;
		}

		return false;
	}

	return true;
}

let speed_modes = [
	[ 'ping,tcp:80,tcp:443', 'ping,tcp:80,tcp:443' ],
	[ 'ping,tcp:443,tcp:80', 'ping,tcp:443,tcp:80' ],
	[ 'tcp:80,tcp:443,ping', 'tcp:80,tcp:443,ping' ],
	[ 'tcp:443,tcp:80,ping', 'tcp:443,tcp:80,ping' ],
	[ 'tcp-syn:80,tcp-syn:443,ping', 'tcp-syn:80,tcp-syn:443,ping' ],
	[ 'tcp-syn:443,tcp-syn:80,ping', 'tcp-syn:443,tcp-syn:80,ping' ],
	[ 'none', 'None' ]
];

let settings_fields = [
	flag('enabled', 'Enable', 'Enable or disable smartdns server'),
	list_of('servers', 'Upstream Server', 'Upstream servers, format: [udp://|tcp://|tls://|https://|quic://|h3://][ip] [options].', { datatype: 'server' }),
	text('ad_block_file', 'AD Block Domain List File', 'Set the file for blocking ad domain names.', { datatype: 'file' }),
	select('server_mode', 'DNS Server Mode', [
		[ 'main', 'Main DNS Server' ],
		[ 'upstream', 'Upstream DNS Server' ],
		[ 'dnsmasq_upstream', 'Dnsmasq Upstream Server' ]
	], 'Smartdns server mode.'),
	num('port', 'DNS Server Port', 'Smartdns server port.', {
		datatype: 'port',
		placeholder: '6053',
		depends: [ { field: 'server_mode', value: 'upstream' }, { field: 'server_mode', value: 'dnsmasq_upstream' } ]
	}),
	text('speed_check_mode', 'Speed Check Mode', 'Smartdns speed check mode.', {
		suggest: [ 'ping,tcp:80,tcp:443', 'tcp-syn:443,tcp-syn:80,ping', 'none' ],
		placeholder: 'default',
		check: check_speed_mode,
		invalid: 'Speed check mode is invalid.'
	}),
	select('response_mode', 'Response Mode', [
		[ '', 'default' ],
		[ 'first-ping', 'First Ping' ],
		[ 'fastest-ip', 'Fastest IP' ],
		[ 'fastest-response', 'Fastest Response' ]
	], 'Smartdns response mode, First Ping: return the first ping IP, Fastest IP: return the fastest IP, Fastest Response: return the fastest DNS response.'),
	flag('dualstack_ip_selection', 'Dual-stack IP Selection', 'Enable IP selection between IPv4 and IPv6'),
	flag('prefetch_domain', 'Domain prefetch', 'Enable domain prefetch, accelerate domain response speed.'),
	flag('serve_expired', 'Serve expired', 'Attempts to serve old responses from cache with a TTL of 0 in the response without waiting for the actual resolution to finish.'),
	num('cache_size', 'Cache Size', 'DNS domain result cache size', { datatype: 'uinteger', placeholder: '8000' }),
	flag('cache_persist', 'Cache Persist', 'Write cache to disk on exit and load on startup.'),
	text('cache_file', 'Cache File', 'Cache persist file path, used when cache persist is enabled.', { placeholder: '/etc/smartdns/smartdns.cache', depends: depends('cache_persist', '1') }),
	flag('resolve_local_hostnames', 'Resolve Local Hostnames', 'Resolve local hostnames by reading Dnsmasq or odhcpd lease files.'),
	flag('mdns_lookup', 'mDNS Lookup', 'Resolve local network hostname via mDNS protocol.'),
	flag('force_aaaa_soa', 'Force AAAA SOA', 'Force AAAA SOA.'),
	flag('force_https_soa', 'Force HTTPS SOA', 'Force HTTPS SOA.'),
	num('rr_ttl', 'Domain TTL', 'TTL for all domain result.', { datatype: 'uinteger' }),
	num('rr_ttl_min', 'Domain TTL Min', 'Minimum TTL for all domain result.', { datatype: 'uinteger', placeholder: '600' }),
	num('rr_ttl_max', 'Domain TTL Max', 'Maximum TTL for all domain result.', { datatype: 'uinteger' }),
	flag('ui', 'Enable WebUI', 'Enable or disable smartdns webui plugin.'),
	num('ui_port', 'WebUI Port', 'WebUI server port.', { datatype: 'port', placeholder: '6080', depends: depends('ui', '1') }),
	text('ui_data_dir', 'WebUI Data Dir', 'Directory for storing the webui database.', { placeholder: '/var/lib/smartdns-lite', depends: depends('ui', '1') }),
	num('ui_log_max_age', 'WebUI Log Retention', 'Number of days to retain webui logs.', { datatype: 'uinteger', placeholder: '30', depends: depends('ui', '1') })
];

let parental_fields = [
	flag('pc_enabled', 'Enable', 'Enable or disable parental control.'),
	list_of('pc_client_addr', 'Client Address', 'If a client address is specified, only that client will apply this rule. You can enter an IP address, such as 1.2.3.4, or a MAC address, such as aa:bb:cc:dd:ee:ff.', { datatype: 'clientaddr' }),
	text('pc_client_addr_file', 'Client Address File', 'Client address list file, one IP address, CIDR or MAC address per line.', { datatype: 'file' }),
	list_of('pc_servers', 'Parental Control Upstream Server', 'Upstream server with parental control feature. If not specified, the default server will be used.', { datatype: 'server' }),
	text('pc_block_file', 'Parental Control Domain File', 'Block Domain List File for Parental Control.', { datatype: 'file' })
];

let rules_fields = [
	flag('rules_enabled', 'Enable', 'Enable or disable domain rules.'),
	text('rules_domain_file', 'Domain List File', 'Upload domain list file for matching these rules, if not specified, the rules will be applied to all domains.', { datatype: 'file' }),
	list_of('rules_servers', 'Upstream Server', 'Upstream server for specific domain. If not specified, the default server will be used.', { datatype: 'server' }),
	text('rules_speed_check_mode', 'Speed Check Mode', 'Speed check mode for matching domains.', {
		suggest: [ 'ping,tcp:80,tcp:443', 'tcp:80,tcp:443,ping', 'none' ],
		placeholder: 'None',
		check: check_speed_mode,
		invalid: 'Speed check mode is invalid.'
	}),
	flag('rules_force_aaaa_soa', 'Force AAAA SOA', 'Force AAAA SOA.'),
	flag('rules_force_https_soa', 'Force HTTPS SOA', 'Force HTTPS SOA.'),
	flag('use_internal_rules', 'Use Internal IP Rules', 'Use internal IP rules to forward data to TPROXY service when the domain matches, avoiding the need to configure IP rules.'),
	text('rules_ipset_name', 'IPset Name', 'IPset name.', { datatype: 'ipset', depends: depends('use_internal_rules', '0') }),
	text('rules_nftset_name', 'NFTset Name', 'NFTset name, format: [#[4|6]:[family#table#set]]', { datatype: 'nftset', depends: depends('use_internal_rules', '0') }),
	num('tproxy_server_port', 'TPROXY Server Port', 'TPROXY server port used for forwarding data requests, please make sure this port has enabled TPROXY service.', { datatype: 'port', depends: depends('use_internal_rules', '1') })
];

let cloudflare_fields = [
	flag('cloudflare_enabled', 'Enable', 'Enable or disable cloudflare cdn ip accelerating.'),
	list_of('cloudflare_ip_alias', 'IP alias', 'IP Address Mapping, mapping all CloudFlare CDN IPs to the specified IP, can be used to accelerate CloudFlare CDN websites.', { datatype: 'ipaddr' }),
	text('cloudflare_cdn_ip_file', 'CloudFlare CDN IP File', 'Upload CloudFlare cdn ip list file, please refer to https://www.cloudflare.com/ips', { datatype: 'file' })
];

function dnsmasq_forwarded(db, port) {
	db.load('dhcp');

	let sid = db.get_first('dhcp', 'dnsmasq');

	if (sid == null)
		return true;

	let section = db.get_all('dhcp', sid);

	if (section == null)
		return true;

	let needle = '127.0.0.1#' + port;
	let server = section.server;

	if (type(server) == 'string')
		server = [ server ];

	for (let entry in (server ?? [])) {
		if (entry + '' == needle)
			return true;
	}

	return false;
}

function hide_webui_fields(app) {
	for (let tab in app.tabs) {
		if (tab.id != 'settings')
			continue;

		for (let block in tab.blocks) {
			if (block.kind != 'fields' || block.fields !== settings_fields)
				continue;

			let kept = [];

			for (let f in block.fields) {
				if (f.name == 'ui' || f.name == 'ui_port' || f.name == 'ui_data_dir' || f.name == 'ui_log_max_age')
					continue;

				push(kept, f);
			}

			block.fields = kept;
		}
	}
}

export const app = {
	conf: 'smartdns-lite',
	section: 'smartdns-lite',
	base: 'admin/services/smartdns-lite',
	title: 'SmartDNS Lite',
	describe: 'A local SmartDNS server for lite users.',
	service: 'smartdns-lite',
	actions: { restart: true },
	setup: function(env, db, app) {
		if (stat('/usr/lib/smartdns_ui.so') != null)
			return;

		if (db.get('smartdns-lite', 'smartdns-lite', 'ui') == '1')
			return;

		hide_webui_fields(app);
	},
	status: function(env, db) {
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

		let enabled = db.get('smartdns-lite', 'smartdns-lite', 'enabled');

		if (!running && enabled == '1')
			push(warnings, 'Please check the system logs and check if the configuration is valid.');

		db.load('smartdns');

		let auto_set = db.get('smartdns', 'smartdns', 'auto_set_dnsmasq');
		let port = db.get('smartdns', 'smartdns', 'port') ?? '53';
		let webui = null;

		if (auto_set == '1' && port != '53' && !dnsmasq_forwarded(db, port))
			push(warnings, 'Dnsmasq Forwarded To Smartdns Failure');

		if (db.get('smartdns-lite', 'smartdns-lite', 'ui') == '1' && stat('/usr/lib/smartdns_ui.so') != null) {
			let host = env.http.getenv('SERVER_NAME') ?? 'localhost';
			let ui_port = db.get('smartdns-lite', 'smartdns-lite', 'ui_port') ?? '6080';

			webui = '//' + host + ':' + ui_port;
		}

		return { running: running, warnings: warnings, webui: webui, legend: 'SmartDNS' };
	},
	tabs: [
		{
			id: 'settings', title: 'Basic Settings', blocks: [
				{ kind: 'fields', fields: settings_fields },
				{ kind: 'upload', name: 'ad_block_file', option: 'ad_block_file', title: 'Upload AD Block Domain List', dir: '/etc/smartdns/domain-set', description: 'The uploaded file is stored under /etc/smartdns/domain-set and is used as the AD block domain list.' }
			]
		},
		{
			id: 'parental', title: 'Parental Control Settings', blocks: [
				{ kind: 'fields', fields: parental_fields },
				{ kind: 'upload', name: 'pc_client_addr_file', option: 'pc_client_addr_file', title: 'Upload Client Address File', dir: '/etc/smartdns/ip-set', description: 'The uploaded file is stored under /etc/smartdns/ip-set.' },
				{ kind: 'upload', name: 'pc_block_file', option: 'pc_block_file', title: 'Upload Parental Control Domain File', dir: '/etc/smartdns/domain-set', description: 'The uploaded file is stored under /etc/smartdns/domain-set.' }
			]
		},
		{
			id: 'rules', title: 'Domain Rules Settings', blocks: [
				{ kind: 'fields', fields: rules_fields },
				{ kind: 'upload', name: 'rules_domain_file', option: 'rules_domain_file', title: 'Upload Domain List File', dir: '/etc/smartdns/domain-set', description: 'The uploaded file is stored under /etc/smartdns/domain-set.' }
			]
		},
		{
			id: 'cloudflare', title: 'CloudFlare CDN IP Settings', blocks: [
				{ kind: 'fields', fields: cloudflare_fields },
				{ kind: 'upload', name: 'cloudflare_cdn_ip_file', option: 'cloudflare_cdn_ip_file', title: 'Upload CloudFlare CDN IP File', dir: '/etc/smartdns/ip-set', description: 'The uploaded file is stored under /etc/smartdns/ip-set.' }
			]
		},
		{
			id: 'custom', title: 'Custom Settings', blocks: [
				{ kind: 'file', name: 'custom', path: '/etc/smartdns/custom.conf', rows: 20, title: 'Custom Configuration', description: 'smartdns custom settings' },
				{
					kind: 'links', title: 'SmartDNS official website', links: [
						{ href: 'https://pymumu.github.io/smartdns', title: 'open website' }
					]
				}
			]
		}
	]
};
