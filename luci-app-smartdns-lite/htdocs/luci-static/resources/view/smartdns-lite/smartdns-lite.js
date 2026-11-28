/*************************************************************************
 *
 * Copyright (C) 2018-2025 Ruilin Peng (Nick) <pymumu@gmail.com>.
 *
 * smartdns is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * smartdns is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


'use strict';
'require fs';
'require uci';
'require form';
'require view';
'require poll';
'require rpc';
'require ui';

/*
 * The lite app runs its own smartdns instance with a generated, standalone
 * configuration, so its status is independent of the full smartdns service.
 */
const conf = 'smartdns-lite';

const callServiceList = rpc.declare({
	object: 'service',
	method: 'list',
	params: ['name'],
	expect: { '': {} }
});

const SERVER_PATTERN = /^(https?|udp|tcp|tls|quic|h3):\/\/[0-9a-zA-Z.\[\]:]+(\/[^\s]*)?$/;

let pollAdded = false;

const getServiceStatus = () => L.resolveDefault(callServiceList(conf), {})
	.then(res => res?.[conf]?.instances?.[conf]?.running ?? false);

const smartdnsServiceStatus = () => Promise.all([
	getServiceStatus(),
	uci.unload('dhcp'),
	uci.load('dhcp')
]);

const smartdnsRenderStatus = (res, hasUi) => {
	const serverMode = uci.get_first('smartdns-lite', 'smartdns-lite', 'server_mode');
	const smartdnsPort = uci.get_first('smartdns-lite', 'smartdns-lite', 'port') ?? '';
	const smartdnsEnable = uci.get_first('smartdns-lite', 'smartdns-lite', 'enabled');
	const dnsmasqServer = uci.get_first('dhcp', 'dnsmasq', 'server') ?? '';
	const uiEnable = uci.get_first('smartdns-lite', 'smartdns-lite', 'ui') ?? '0';
	const uiPort = uci.get_first('smartdns-lite', 'smartdns-lite', 'ui_port') ?? '6080';

	const nodes = [];

	if (!res[0]) {
		nodes.push(E('span', { style: 'color:red;font-weight:bold' }, `${_('SmartDNS Lite')} - ${_('NOT RUNNING')}`));

		if (smartdnsEnable === '1')
			nodes.push(E('br'), E('span', { style: 'color:red;font-weight:bold' },
				_('Please check the system logs and check if the configuration is valid.')));

		return nodes;
	}

	nodes.push(E('span', { style: 'color:green;font-weight:bold' }, `${_('SmartDNS Lite')} - ${_('RUNNING')}`));

	if (uiEnable === '1' && hasUi)
		nodes.push(' ', E('a', {
			class: 'btn cbi-button',
			href: `${window.location.protocol}//${window.location.hostname}:${uiPort}`,
			target: '_blank',
			rel: 'noopener'
		}, _('Open the WebUI')));

	if (serverMode === 'dnsmasq_upstream' && smartdnsPort && smartdnsPort !== '53' &&
	    !dnsmasqServer.includes(`127.0.0.1#${smartdnsPort}`))
		nodes.push(E('br'), E('span', { style: 'color:red;font-weight:bold' },
			_('Dnsmasq Forwarded To Smartdns Failure')));

	return nodes;
};

const validateServer = (section_id, value) => {
	if (!value)
		return true;

	for (const server of value.split(/\s+/)) {
		if (!SERVER_PATTERN.test(server))
			return _('Invalid server address: %s').replace('%s', server);
	}

	return true;
};

const validateClientAddr = (section_id, value) => {
	if (!value)
		return true;

	if (/^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\/([0-9]|[1-2][0-9]|3[0-2]))?$/.test(value))
		return true;

	if (/^([a-fA-F0-9]*:){1,7}[a-fA-F0-9]*(\/([0-9]|[1-9][0-9]|1[0-1][0-9]|12[0-8]))?$/.test(value))
		return true;

	if (/^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/.test(value))
		return true;

	return _('Client address format error, please input IP address or MAC address.');
};

const isSmartdnsUiAvailable = () => fs.stat('/usr/lib/smartdns_ui.so')
	.then(res => res?.type === 'file')
	.catch(() => false);

return view.extend({
	load() {
		return Promise.all([
			uci.load('dhcp'),
			uci.load('smartdns-lite'),
			isSmartdnsUiAvailable()
		]);
	},

	render([, , hasUi]) {
		let m, s, o;

		m = new form.Map('smartdns-lite', _('SmartDNS Lite'));
		m.title = _('SmartDNS Lite');
		m.description = _('A local SmartDNS server for lite users.');

		s = m.section(form.NamedSection, '_status');
		s.anonymous = true;
		s.render = () => {
			const renderStatus = () => L.resolveDefault(smartdnsServiceStatus()).then(res => {
				document.getElementById('service_status')
					?.replaceChildren(...smartdnsRenderStatus(res, hasUi));
			});

			if (!pollAdded) {
				poll.add(renderStatus, 1);
				pollAdded = true;
			}

			return E('div', { class: 'cbi-section' },
				E('div', { id: 'service_status' }, _('Collecting data ...')));
		};

		////////////////
		// Basic;
		////////////////
		s = m.section(form.TypedSection, 'smartdns-lite', _('Settings'));
		s.anonymous = true;

		s.tab('settings', _('Basic Settings'));
		s.tab('parental', _('Parental Control Settings'));
		s.tab('rules', _('Domain Rules Settings'));
		s.tab('cloudflare', _('CloudFlare CDN IP Settings'),
			_('Set the IP addresses for accelerating CloudFlare CDN.'));
		s.tab('custom', _('Custom Settings'));

		///////////////////////////////////////
		// Basic Settings
		///////////////////////////////////////
		o = s.taboption('settings', form.Flag, 'enabled', _('Enable'),
			_('Enable or disable smartdns server'));
		o.rmempty = false;
		o.default = o.disabled;

		o = s.taboption('settings', form.DynamicList, 'servers', _('Upstream Server'),
			_('Upstream servers, format: [udp://|tcp://|tls://|https://|quic://|h3://][ip].'));
		o.rmempty = true;
		o.validate = validateServer;

		o = s.taboption('settings', form.FileUpload, 'ad_block_file', _('AD Block Domain List File'),
			_('Set the file for blocking ad domain names.'));
		o.rmempty = true;
		o.datatype = 'file';
		o.editable = true;
		o.root_directory = '/etc/smartdns-lite/domain-set';

		o = s.taboption('settings', form.ListValue, 'server_mode', _('DNS Server Mode'),
			_('Smartdns server mode.'));
		o.rmempty = false;
		o.default = 'main';
		o.value('main', _('Main DNS Server'));
		o.value('upstream', _('Upstream DNS Server'));
		o.value('dnsmasq_upstream', _('Dnsmasq Upstream Server'));

		o = s.taboption('settings', form.Value, 'port', _('DNS Server Port'),
			_('Smartdns server port.'));
		o.rmempty = true;
		o.placeholder = 6053;
		o.default = 6053;
		o.datatype = 'port';
		o.depends('server_mode', 'upstream');
		o.depends('server_mode', 'dnsmasq_upstream');

		////////////////
		// Resolver and cache;
		////////////////
		o = s.taboption('settings', form.Value, 'speed_check_mode', _('Speed Check Mode'),
			_('Smartdns speed check mode.'));
		o.rmempty = true;
		o.placeholder = 'default';
		o.default = 'tcp-syn:443,tcp-syn:80,ping';
		o.value('', _('default'));
		o.value('ping,tcp:80,tcp:443');
		o.value('ping,tcp:443,tcp:80');
		o.value('tcp:80,tcp:443,ping');
		o.value('tcp:443,tcp:80,ping');
		o.value('tcp-syn:80,tcp-syn:443,ping');
		o.value('tcp-syn:443,tcp-syn:80,ping');
		o.value('none', _('None'));
		o.validate = function (section_id, value) {
			if (value === '')
				return true;

			if (value === 'none')
				return true;

			const check_mode = value.split(',');

			for (const cm of check_mode) {
				if (cm === 'ping')
					continue;

				if (cm.startsWith('tcp:')) {
					const tcp_port = cm.split(':')[1];

					if (tcp_port === '')
						return _('TCP port is empty');

					continue;
				}

				if (cm.startsWith('tcp-syn:')) {
					const syn_port = cm.split(':')[1];

					if (syn_port === '')
						return _('TCP SYN port is empty');

					continue;
				}

				return _('Speed check mode is invalid.');
			}

			return true;
		};

		o = s.taboption('settings', form.ListValue, 'response_mode', _('Response Mode'),
			_('Smartdns response mode, First Ping: return the first ping IP, Fastest IP: return the fastest IP, Fastest Response: return the fastest DNS response.'));
		o.rmempty = true;
		o.placeholder = 'default';
		o.default = 'first-ping';
		o.value('', _('default'));
		o.value('first-ping', _('First Ping'));
		o.value('fastest-ip', _('Fastest IP'));
		o.value('fastest-response', _('Fastest Response'));

		o = s.taboption('settings', form.Flag, 'dualstack_ip_selection', _('Dual-stack IP Selection'),
			_('Enable IP selection between IPv4 and IPv6'));
		o.rmempty = false;
		o.default = o.enabled;

		o = s.taboption('settings', form.Flag, 'prefetch_domain', _('Domain prefetch'),
			_('Enable domain prefetch, accelerate domain response speed.'));
		o.rmempty = true;
		o.default = o.enabled;

		o = s.taboption('settings', form.Flag, 'serve_expired', _('Serve expired'),
			_('Attempts to serve old responses from cache with a TTL of 0 in the response without waiting for the actual resolution to finish.'));
		o.rmempty = false;
		o.default = o.enabled;

		o = s.taboption('settings', form.Value, 'cache_size', _('Cache Size'),
			_('DNS domain result cache size'));
		o.rmempty = true;
		o.placeholder = '8000';
		o.default = 8000;

		o = s.taboption('settings', form.Flag, 'cache_persist', _('Cache Persist'),
			_('Write cache to disk on exit and load on startup.'));
		o.rmempty = false;
		o.default = o.enabled;

		o = s.taboption('settings', form.Value, 'cache_file', _('Cache File'),
			_('Cache persist file path, used when cache persist is enabled.'));
		o.placeholder = '/etc/smartdns-lite/smartdns.cache';
		o.datatype = 'string';
		o.rmempty = true;
		o.depends('cache_persist', '1');

		o = s.taboption('settings', form.Flag, 'resolve_local_hostnames', _('Resolve Local Hostnames'),
			_('Resolve local hostnames by reading Dnsmasq or odhcpd lease files.'));
		o.rmempty = false;
		o.default = o.enabled;

		o = s.taboption('settings', form.Flag, 'mdns_lookup', _('mDNS Lookup'),
			_('Resolve local network hostname via mDNS protocol.'));
		o.rmempty = true;
		o.default = o.enabled;

		o = s.taboption('settings', form.Flag, 'force_aaaa_soa', _('Force AAAA SOA'),
			_('Force AAAA SOA.'));
		o.rmempty = true;
		o.default = o.disabled;

		o = s.taboption('settings', form.Flag, 'force_https_soa', _('Force HTTPS SOA'),
			_('Force HTTPS SOA.'));
		o.rmempty = false;
		o.default = o.enabled;

		o = s.taboption('settings', form.Value, 'rr_ttl', _('Domain TTL'),
			_('TTL for all domain result.'));
		o.rmempty = true;

		o = s.taboption('settings', form.Value, 'rr_ttl_min', _('Domain TTL Min'),
			_('Minimum TTL for all domain result.'));
		o.rmempty = true;
		o.placeholder = '600';
		o.default = 600;

		o = s.taboption('settings', form.Value, 'rr_ttl_max', _('Domain TTL Max'),
			_('Maximum TTL for all domain result.'));
		o.rmempty = true;

		////////////////
		// WebUI;
		////////////////
		if (hasUi || uci.get_first('smartdns-lite', 'smartdns-lite', 'ui') === '1') {
			o = s.taboption('settings', form.Flag, 'ui', _('Enable WebUI'),
				_('Enable or disable smartdns webui plugin.'));
			o.rmempty = false;
			o.default = o.disabled;

			o = s.taboption('settings', form.Value, 'ui_port', _('WebUI Port'),
				_('WebUI server port.'));
			o.placeholder = 6080;
			o.datatype = 'port';
			o.rmempty = true;
			o.depends('ui', '1');

			o = s.taboption('settings', form.Value, 'ui_data_dir', _('WebUI Data Dir'),
				_('Directory for storing the webui database.'));
			o.placeholder = '/var/lib/smartdns-lite';
			o.datatype = 'string';
			o.rmempty = true;
			o.depends('ui', '1');

			o = s.taboption('settings', form.Value, 'ui_log_max_age', _('WebUI Log Retention'),
				_('Number of days to retain webui logs.'));
			o.placeholder = 30;
			o.datatype = 'uinteger';
			o.rmempty = true;
			o.depends('ui', '1');
		}

		///////////////////////////////////////
		// Parental Control Settings
		///////////////////////////////////////
		o = s.taboption('parental', form.Flag, 'pc_enabled', _('Enable'),
			_('Enable or disable parental control.'));
		o.rmempty = false;
		o.default = o.disabled;
		o.validate = function (section_id, value) {
			const pc_enabled = this.map.lookupOption('pc_enabled', section_id)?.[0]?.formvalue(section_id);
			const server_mode = this.map.lookupOption('server_mode', section_id)?.[0]?.formvalue(section_id);

			if (pc_enabled !== '1' || server_mode === 'main')
				return true;

			return _('Parental control feature is only available in Main DNS mode.');
		};

		o = s.taboption('parental', form.DynamicList, 'pc_client_addr', _('Client Address'),
			_('If a client address is specified, only that client will apply this rule. You can enter an IP address, such as 1.2.3.4, or a MAC address, such as aa:bb:cc:dd:ee:ff.'));
		o.rmempty = true;
		o.validate = validateClientAddr;

		o = s.taboption('parental', form.FileUpload, 'pc_client_addr_file', _('Client Address File'),
			_('Client address list file, one IP address, CIDR or MAC address per line.'));
		o.rmempty = true;
		o.datatype = 'file';
		o.editable = true;
		o.root_directory = '/etc/smartdns-lite/ip-set';

		o = s.taboption('parental', form.DynamicList, 'pc_servers', _('Parental Control Upstream Server'),
			_('Upstream server with parental control feature. If not specified, the default server will be used.'));
		o.rmempty = true;
		o.validate = validateServer;

		o = s.taboption('parental', form.FileUpload, 'pc_block_file', _('Parental Control Domain File'),
			_('Block Domain List File for Parental Control.'));
		o.rmempty = true;
		o.datatype = 'file';
		o.editable = true;
		o.root_directory = '/etc/smartdns-lite/domain-set';

		///////////////////////////////////////
		// Domain Rules Settings
		///////////////////////////////////////
		o = s.taboption('rules', form.Flag, 'rules_enabled', _('Enable'),
			_('Enable or disable domain rules.'));
		o.rmempty = false;
		o.default = o.disabled;

		o = s.taboption('rules', form.FileUpload, 'rules_domain_file', _('Domain List File'),
			_('Upload domain list file for matching these rules, if not specified, the rules will be applied to all domains.'));
		o.rmempty = true;
		o.datatype = 'file';
		o.editable = true;
		o.root_directory = '/etc/smartdns-lite/domain-set';

		o = s.taboption('rules', form.DynamicList, 'rules_servers', _('Upstream Server'),
			_('Upstream server for specific domain. If not specified, the default server will be used.'));
		o.rmempty = true;
		o.validate = validateServer;

		o = s.taboption('rules', form.Value, 'rules_speed_check_mode', _('Speed Check Mode'),
			_('Speed check mode for matching domains.'));
		o.rmempty = true;
		o.placeholder = _('None');
		o.value('none', _('None'));
		o.value('ping,tcp:80,tcp:443');
		o.value('ping,tcp:443,tcp:80');
		o.value('tcp:80,tcp:443,ping');
		o.value('tcp:443,tcp:80,ping');
		o.validate = function (section_id, value) {
			if (!value || value === 'none')
				return true;

			for (const mode of value.split(',')) {
				if (mode === 'ping')
					continue;

				if (mode.startsWith('tcp:')) {
					if (!mode.split(':')[1])
						return _('TCP port is empty');

					continue;
				}

				return _('Speed check mode is invalid.');
			}

			return true;
		};

		o = s.taboption('rules', form.Flag, 'rules_force_aaaa_soa', _('Force AAAA SOA'),
			_('Force AAAA SOA.'));
		o.rmempty = true;
		o.default = o.disabled;

		o = s.taboption('rules', form.Flag, 'rules_force_https_soa', _('Force HTTPS SOA'),
			_('Force HTTPS SOA.'));
		o.rmempty = true;
		o.default = o.enabled;

		o = s.taboption('rules', form.Flag, 'use_internal_rules', _('Use Internal IP Rules'),
			_('Use internal IP rules to forward data to TPROXY service when the domain matches, avoiding the need to configure IP rules.'));
		o.rmempty = true;
		o.default = o.disabled;

		o = s.taboption('rules', form.Value, 'rules_ipset_name', _('IPset Name'), _('IPset name.'));
		o.rmempty = true;
		o.datatype = 'string';
		o.validate = function (section_id, value) {
			if (!value)
				return true;

			for (const ipset of value.split(',')) {
				if (!/^(#[4|6]:)?[a-zA-Z0-9\-_]+$/.test(ipset))
					return _('ipset name format error, format: [#[4|6]:]ipsetname');
			}

			return true;
		};
		o.depends('use_internal_rules', '0');

		o = s.taboption('rules', form.Value, 'rules_nftset_name', _('NFTset Name'),
			_('NFTset name, format: [#[4|6]:[family#table#set]]'));
		o.rmempty = true;
		o.datatype = 'string';
		o.validate = function (section_id, value) {
			if (!value)
				return true;

			for (const nftset of value.split(',')) {
				if (!/^#[4|6]:[a-zA-Z0-9\-_]+#[a-zA-Z0-9\-_]+#[a-zA-Z0-9\-_]+$/.test(nftset))
					return _('NFTset name format error, format: [#[4|6]:[family#table#set]]');
			}

			return true;
		};
		o.depends('use_internal_rules', '0');

		o = s.taboption('rules', form.Value, 'tproxy_server_port', _('TPROXY Server Port'),
			_('TPROXY server port used for forwarding data requests, please make sure this port has enabled TPROXY service.'));
		o.rmempty = false;
		o.datatype = 'port';
		o.depends('use_internal_rules', '1');
		o.validate = function (section_id, value) {
			const use_internal_rules = this.map.lookupOption('use_internal_rules', section_id)?.[0]?.formvalue(section_id);

			if (use_internal_rules === '1' && !value)
				return _('A TPROXY server port is required when using internal IP rules.');

			return true;
		};

		///////////////////////////////////////
		// CloudFlare CDN IP Settings
		///////////////////////////////////////
		o = s.taboption('cloudflare', form.Flag, 'cloudflare_enabled', _('Enable'),
			_('Enable or disable cloudflare cdn ip accelerating.'));
		o.rmempty = false;
		o.default = o.disabled;

		o = s.taboption('cloudflare', form.FileUpload, 'cloudflare_cdn_ip_file', _('CloudFlare CDN IP File'),
			_('Upload CloudFlare cdn ip list file, please refer to https://www.cloudflare.com/ips'));
		o.rmempty = true;
		o.datatype = 'file';
		o.modalonly = true;
		o.root_directory = '/etc/smartdns-lite/ip-set';

		o = s.taboption('cloudflare', form.DynamicList, 'cloudflare_ip_alias', _('IP alias'),
			_('IP Address Mapping, mapping all CloudFlare CDN IPs to the specified IP, can be used to accelerate CloudFlare\'s CDN websites.'));
		o.rmempty = true;
		o.datatype = 'ipaddr("nomask")';
		o.modalonly = true;

		///////////////////////////////////////
		// Custom Settings
		///////////////////////////////////////
		o = s.taboption('custom', form.TextValue, 'custom_conf',
			'', _('smartdns custom settings'));
		o.rows = 20;
		o.cfgvalue = section_id => fs.trimmed('/etc/smartdns-lite/custom.conf');
		o.write = function (section_id, formvalue) {
			return this.cfgvalue(section_id).then(value => {
				if (value === formvalue)
					return;

				return fs.write('/etc/smartdns-lite/custom.conf',
					`${formvalue.trim().replace(/\r\n/g, '\n')}\n`);
			});
		};

		o = s.taboption('custom', form.Button, 'web');
		o.title = _('SmartDNS official website');
		o.inputtitle = _('open website');
		o.inputstyle = 'apply';
		o.onclick = () => window.open('https://pymumu.github.io/smartdns', '_blank', 'noopener');

		o = s.taboption('custom', form.DummyValue, '_restart', _('Restart Service'));
		o.renderWidget = function () {
			return E('button', {
				class: 'btn cbi-button cbi-button-apply',
				id: 'btn_restart',
				click: ui.createHandlerFn(this, () => fs.exec('/etc/init.d/smartdns-lite', ['restart'])
					.catch(e => ui.addNotification(null, E('p', e.message), 'error')))
			}, [_('Restart')]);
		};

		return m.render();
	}
});
