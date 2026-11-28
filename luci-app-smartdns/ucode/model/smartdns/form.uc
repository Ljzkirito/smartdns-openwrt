// SPDX-License-Identifier: GPL-3.0-or-later
// ============================================================================
// Server-side form engine for the SmartDNS LuCI applications.
//
// This file is installed by luci-app-smartdns as luci.model.smartdns.form.
// luci-app-smartdns-lite ships a byte-identical copy of it at
// ucode/model/smartdns_lite/form.uc, installed as luci.model.smartdns_lite.form.
// Keep the two copies in sync whenever the engine changes.
//
// The engine renders classic server-side CBI markup (cbi-value, cbi-section,
// cbi-tabmenu, ...) from a declarative schema, and applies POSTed values to
// UCI (plus a few plain files and uploads) without any client side form
// framework, so it works the same on LuCI 24.10, 25.12 and master.
// ============================================================================

import { writefile, readfile, mkdir, stat, popen, basename } from 'fs';

let translate = (s) => s;

function t(s) {
	if (s == null)
		return '';

	return translate(s);
}

function esc(v) {
	if (v == null)
		return '';

	let s = v + '';
	let out = '';

	for (let i = 0; i < length(s); i++) {
		let c = substr(s, i, 1);

		switch (c) {
		case '&':
			out += '&amp;';
			break;
		case '<':
			out += '&lt;';
			break;
		case '>':
			out += '&gt;';
			break;
		case '"':
			out += '&quot;';
			break;
		case "'":
			out += '&#39;';
			break;
		default:
			out += c;
		}
	}

	return out;
}

function first(v) {
	if (type(v) == 'array')
		return length(v) ? v[0] : null;

	return v;
}

function to_array(v) {
	if (v == null)
		return [];

	if (type(v) == 'array')
		return v;

	return [ v ];
}

function trim_str(v) {
	if (v == null)
		return '';

	return trim(v + '');
}

function to_lines(v) {
	let lines = [];

	if (v == null)
		return lines;

	for (let raw in to_array(v)) {
		if (raw == null)
			continue;

		for (let line in split(raw + '', chr(10))) {
			line = trim(line);

			if (length(line))
				push(lines, line);
		}
	}

	return lines;
}

function join_lines(arr) {
	let out = '';

	for (let i = 0; i < length(arr); i++) {
		if (i)
			out += chr(10);

		out += arr[i];
	}

	return out;
}

function truthy(v) {
	if (v == null)
		return false;

	if (type(v) == 'array')
		v = first(v);

	if (v == null)
		return false;

	let s = lc(v + '');

	return (s == '1' || s == 'true' || s == 'on' || s == 'yes' || s == 'enabled');
}

function value_of(v) {
	if (v == null)
		return '';

	if (type(v) == 'array')
		v = first(v);

	if (v == null)
		return '';

	return v + '';
}

function has_value(v) {
	if (v == null)
		return false;

	if (type(v) == 'array')
		return length(v) > 0;

	return length(v + '') > 0;
}

// ---------------------------------------------------------------------------
// Validators
// ---------------------------------------------------------------------------

function digits(s, minlen, maxlen) {
	let n = length(s);

	if (n < minlen || n > maxlen)
		return false;

	for (let i = 0; i < n; i++) {
		let c = substr(s, i, 1);

		if (c < '0' || c > '9')
			return false;
	}

	return true;
}

function hexgroup(s) {
	if (!length(s) || length(s) > 4)
		return false;

	for (let i = 0; i < length(s); i++) {
		let c = lc(substr(s, i, 1));

		if (!(c >= '0' && c <= '9') && !(c >= 'a' && c <= 'f'))
			return false;
	}

	return true;
}

function valid_v4(s) {
	let parts = split(s, '.');

	if (length(parts) != 4)
		return false;

	for (let p in parts) {
		if (!digits(p, 1, 3))
			return false;

		if (int(p) > 255)
			return false;
	}

	return true;
}

function valid_v6(s) {
	if (index(s, ':') < 0)
		return false;

	if (index(s, ':::') >= 0)
		return false;

	if (substr(s, 0, 1) == ':' && substr(s, 0, 2) != '::')
		return false;

	if (substr(s, length(s) - 1) == ':' && substr(s, length(s) - 2) != '::')
		return false;

	let rest = s;
	let double_colon = 0;
	let pos;

	while ((pos = index(rest, '::')) >= 0) {
		double_colon++;

		if (double_colon > 1)
			return false;

		rest = substr(rest, pos + 2);
	}

	let parts = split(s, ':');
	let groups = 0;

	for (let k = 0; k < length(parts); k++) {
		let p = parts[k];

		if (!length(p))
			continue;

		if (index(p, '.') >= 0) {
			if (k != length(parts) - 1 || !valid_v4(p))
				return false;

			groups += 2;
			continue;
		}

		if (!hexgroup(p))
			return false;

		groups++;
	}

	if (double_colon)
		return groups < 8;

	return groups == 8;
}

function valid_cidr(s, family) {
	let parts = split(s, '/');

	if (length(parts) != 2)
		return false;

	if (family == 4) {
		return valid_v4(parts[0]) && digits(parts[1], 1, 2) && int(parts[1]) <= 32;
	}

	if (family == 6) {
		return valid_v6(parts[0]) && digits(parts[1], 1, 3) && int(parts[1]) <= 128;
	}

	return valid_cidr(s, 4) || valid_cidr(s, 6);
}

function valid_ip(s) {
	return valid_v4(s) || valid_v6(s);
}

function valid_mac(s) {
	let normalized = '';

	for (let i = 0; i < length(s); i++) {
		let c = substr(s, i, 1);

		if (c == ':' || c == '-')
			normalized += ':';
		else
			normalized += c;
	}

	let parts = split(normalized, ':');

	if (length(parts) != 6)
		return false;

	for (let p in parts) {
		if (length(p) != 2 || !hexgroup(p))
			return false;
	}

	return true;
}

function valid_ident(s) {
	if (!length(s))
		return false;

	for (let i = 0; i < length(s); i++) {
		let c = lc(substr(s, i, 1));

		if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-' || c == '_')
			continue;

		return false;
	}

	return true;
}

function valid_host(s) {
	if (!length(s) || length(s) > 253)
		return false;

	for (let i = 0; i < length(s); i++) {
		let c = lc(substr(s, i, 1));

		if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9'))
			continue;

		if (c == '.' || c == '-' || c == '_' || c == ':' || c == '[' || c == ']')
			continue;

		return false;
	}

	return true;
}

function valid_domain(s) {
	if (!length(s))
		return false;

	for (let i = 0; i < length(s); i++) {
		let c = lc(substr(s, i, 1));

		if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9'))
			continue;

		if (c == '.' || c == '-' || c == '_' || c == '*')
			continue;

		return false;
	}

	return true;
}

let url_schemes = [ 'udp', 'tcp', 'tls', 'https', 'http', 'quic', 'h3', 'ftp', 'sftp', 'socks5', 'socks5h' ];

function valid_url(s) {
	let pos = index(s, '://');

	if (pos < 0)
		return false;

	let scheme = lc(substr(s, 0, pos));
	let known = false;

	for (let candidate in url_schemes) {
		if (candidate == scheme)
			known = true;
	}

	if (!known)
		return false;

	if (length(s) <= pos + 3)
		return false;

	for (let i = pos + 3; i < length(s); i++) {
		let c = substr(s, i, 1);

		if (c == ' ' || c == chr(9))
			return false;
	}

	return true;
}

// Server address as accepted by the "server" option, e.g.
//   udp://8.8.8.8, tls://dns.example.com:853 -host-name example.com
function valid_plain_server(s) {
	let addr = s;
	let sp = index(addr, ' ');

	if (sp >= 0)
		addr = substr(addr, 0, sp);

	if (!length(addr))
		return false;

	if (substr(addr, 0, 1) == '[') {
		let close = index(addr, ']');

		if (close < 0 || !valid_v6(substr(addr, 1, close - 1)))
			return false;

		let rest = substr(addr, close + 1);

		if (!length(rest))
			return true;

		if (substr(rest, 0, 1) != ':' || !digits(substr(rest, 1), 1, 5))
			return false;

		return int(substr(rest, 1)) <= 65535;
	}

	let host = addr;
	let first = index(addr, ':');

	if (first >= 0) {
		let rest = substr(addr, first + 1);

		if (index(rest, ':') >= 0)
			return valid_v6(addr);

		if (!digits(rest, 1, 5) || int(rest) > 65535)
			return false;

		host = substr(addr, 0, first);
	}

	if (!length(host))
		return false;

	return valid_ip(host) || valid_host(host);
}

function valid_server(s) {
	let pos = index(s, '://');

	if (pos < 0)
		return valid_plain_server(s);

	let scheme = lc(substr(s, 0, pos));
	let known = false;

	for (let candidate in url_schemes) {
		if (candidate == scheme)
			known = true;
	}

	if (!known)
		return false;

	let rest = substr(s, pos + 3);

	if (!length(rest))
		return false;

	for (let i = 0; i < length(rest); i++) {
		let c = substr(rest, i, 1);

		if (c == ' ' || c == chr(9))
			continue;

		let l = lc(c);

		if ((l >= 'a' && l <= 'z') || (l >= '0' && l <= '9'))
			continue;

		if (index('. :[]/_?=&@%#+-', c) >= 0)
			continue;

		return false;
	}

	return true;
}

function valid_ipset(s) {
	let body = s;

	if (substr(body, 0, 3) == '#4:' || substr(body, 0, 3) == '#6:')
		body = substr(body, 3);
	else if (substr(body, 0, 1) == '#')
		return false;

	return valid_ident(body);
}

function valid_nftset(s) {
	if (substr(s, 0, 3) != '#4:' && substr(s, 0, 3) != '#6:')
		return false;

	let parts = split(substr(s, 3), '#');

	if (length(parts) != 3)
		return false;

	for (let p in parts) {
		if (!valid_ident(p))
			return false;
	}

	return true;
}

let datatypes = {
	port: function(v) { return digits(v, 1, 5) && int(v) <= 65535; },
	uinteger: function(v) { return digits(v, 1, 10); },
	integer: function(v) {
		let s = v;

		if (substr(s, 0, 1) == '-')
			s = substr(s, 1);

		return digits(s, 1, 10);
	},
	ipv4: valid_v4,
	ipv6: valid_v6,
	ipaddr: valid_ip,
	cidr4: function(v) { return valid_cidr(v, 4); },
	cidr6: function(v) { return valid_cidr(v, 6); },
	cidr: function(v) { return valid_cidr(v, 0); },
	mac: valid_mac,
	hostname: valid_host,
	iplist: function(v) {
		let parts = split(v, ',');

		for (let p in parts) {
			let item = trim_str(p);

			if (!length(item))
				return false;

			if (!valid_ip(item) && !valid_cidr(item, 4) && !valid_cidr(item, 6))
				return false;
		}

		return true;
	},
	domain: valid_domain,
	url: valid_url,
	server: valid_server,
	ipset: valid_ipset,
	nftset: valid_nftset,
	file: function(v) {
		if (!length(v) || index(v, '..') >= 0)
			return false;

		for (let i = 0; i < length(v); i++) {
			let c = substr(v, i, 1);

			if (c == chr(32) || c == chr(9))
				return false;
		}

		return true;
	},
	clientaddr: function(v) {
		return valid_mac(v) || valid_ip(v) || valid_cidr(v, 4) || valid_cidr(v, 6);
	}
};

function title_of(f) {
	return t(f.title ?? f.name);
}

function required_msg(f) {
	return sprintf(t('%s is required.'), title_of(f));
}

function invalid_msg(f) {
	if (f.invalid != null)
		return t(f.invalid);

	return sprintf(t('%s is invalid.'), title_of(f));
}

function validate_item(f, v) {
	if (!length(v)) {
		if (f.required)
			return required_msg(f);

		return null;
	}

	let check = datatypes[f.datatype];

	if (check != null && !check(v))
		return invalid_msg(f);

	if (type(f.check) == 'function' && !f.check(v))
		return invalid_msg(f);

	return null;
}

function validate_value(f, v) {
	if (f.type == 'list') {
		let items = to_lines(v);

		if (!length(items))
			return f.required ? required_msg(f) : null;

		for (let item in items) {
			let err = validate_item(f, item);

			if (err != null)
				return err;
		}

		return null;
	}

	return validate_item(f, value_of(v));
}

// ---------------------------------------------------------------------------
// Field rendering
// ---------------------------------------------------------------------------

function field_key(f, prefix) {
	return (prefix ?? '') + f.name;
}

function depends_attr(f) {
	if (f.depends == null || !length(f.depends))
		return '';

	return " data-depends='" + sprintf('%J', f.depends) + "'";
}

function option_pairs(f) {
	let out = [];

	if (type(f.values) == 'array') {
		for (let e in f.values) {
			if (type(e) == 'array')
				push(out, [ value_of(e[0]), value_of(e[1]) ]);
			else
				push(out, [ value_of(e), value_of(e) ]);
		}
	}
	else if (type(f.values) == 'object') {
		for (let k, v in f.values)
			push(out, [ value_of(k), value_of(v) ]);
	}

	return out;
}

function render_flag(f, value, prefix) {
	let id = esc(field_key(f, prefix));
	let out = '<input type="checkbox" id="' + id + '" name="' + id + '" value="1"';

	if (truthy(value))
		out += ' checked="checked"';

	out += ' /> <label for="' + id + '">' + esc(t(f.checkbox ?? 'Enable')) + '</label>';

	return out;
}

function render_select(f, value, prefix) {
	let id = esc(field_key(f, prefix));
	let current = value_of(value);
	let pairs = option_pairs(f);
	let out = '<select id="' + id + '" name="' + id + '" class="cbi-input-select">';
	let found = false;

	for (let pair in pairs) {
		let selected = '';

		if (pair[0] == current) {
			selected = ' selected="selected"';
			found = true;
		}

		out += '<option value="' + esc(pair[0]) + '"' + selected + '>' + esc(t(pair[1])) + '</option>';
	}

	if (!found && length(current))
		out += '<option value="' + esc(current) + '" selected="selected">' + esc(current) + '</option>';

	out += '</select>';

	return out;
}

function render_textarea(f, value, prefix) {
	let id = esc(field_key(f, prefix));
	let rows = f.rows ?? 5;
	let cols = f.cols ?? 64;
	let content = '';

	if (f.type == 'list')
		content = join_lines(to_lines(value));
	else
		content = value_of(value);

	let out = '<textarea id="' + id + '" name="' + id + '" rows="' + rows + '" cols="' + cols + '" class="cbi-input-textarea" wrap="off"';

	if (f.monospace != false)
		out += ' style="font-family:monospace"';

	out += '>' + esc(content) + '</textarea>';

	return out;
}

function render_input(f, value, prefix, kind) {
	let id = esc(field_key(f, prefix));
	let current = value_of(value);
	let attrs = '';
	let out = '';

	if (f.placeholder != null)
		attrs += ' placeholder="' + esc(t(f.placeholder)) + '"';

	if (f.datatype == 'port') {
		attrs += ' min="1" max="65535"';
	}
	else if (f.datatype == 'uinteger') {
		attrs += ' min="0"';
	}

	if (kind == 'number') {
		if (f.min != null)
			attrs += ' min="' + esc(f.min) + '"';

		if (f.max != null)
			attrs += ' max="' + esc(f.max) + '"';

		if (f.step != null)
			attrs += ' step="' + esc(f.step) + '"';
	}

	if (f.suggest != null && length(f.suggest)) {
		out += '<datalist id="' + id + '.dl">';

		for (let s in f.suggest)
			out += '<option value="' + esc(s) + '"></option>';

		out += '</datalist>';
		attrs += ' list="' + id + '.dl"';
	}

	if (kind == 'number') {
		out += '<input type="number" id="' + id + '" name="' + id + '" class="cbi-input-text" value="' + esc(current) + '"' + attrs + ' />';
	}
	else if (kind == 'password') {
		out += '<input type="password" id="' + id + '" name="' + id + '" class="cbi-input-text" value="' + esc(current) + '"' + attrs + ' />';
	}
	else {
		out += '<input type="text" id="' + id + '" name="' + id + '" class="cbi-input-text" value="' + esc(current) + '"' + attrs + ' />';
	}

	return out;
}

function render_control(f, value, prefix) {
	if (f.type == 'flag')
		return render_flag(f, value, prefix);

	if (f.type == 'select')
		return render_select(f, value, prefix);

	if (f.type == 'textarea' || f.type == 'list')
		return render_textarea(f, value, prefix);

	if (f.type == 'number')
		return render_input(f, value, prefix, 'number');

	if (f.type == 'password')
		return render_input(f, value, prefix, 'password');

	return render_input(f, value, prefix, 'text');
}

function render_field(f, value, error, prefix) {
	let id = esc(field_key(f, prefix));
	let out = '<div class="cbi-value">';

	out += '<label class="cbi-value-title" for="' + id + '">' + esc(title_of(f)) + '</label>';
	out += '<div class="cbi-value-field">' + render_control(f, value, prefix) + '</div>';
	out += '</div>';

	if (f.description != null)
		out += '<div class="cbi-value-description">' + esc(t(f.description)) + '</div>';

	if (error != null)
		out += '<div class="cbi-value-description" style="color:#c43c35">' + esc(error) + '</div>';

	if (f.depends != null && length(f.depends))
		out = '<div' + depends_attr(f) + '>' + out + '</div>';

	return out;
}

function render_fields(fields, values, errors, prefix) {
	let out = '';

	for (let f in fields) {
		let key = field_key(f, prefix);
		let value = null;

		if (values != null)
			value = values[f.name];

		out += render_field(f, value, errors != null ? errors[key] : null, prefix);
	}

	return out;
}

// ---------------------------------------------------------------------------
// UCI helpers
// ---------------------------------------------------------------------------

function read_section(db, conf, sid) {
	if (sid == null)
		return {};

	return db.get_all(conf, sid) ?? {};
}

function ensure_section(db, app) {
	let sid = db.get_first(app.conf, app.section);

	if (sid == null)
		sid = db.add(app.conf, app.section);

	return sid;
}

function section_rows(db, conf, type) {
	let rows = [];

	for (let sid, section in (db.get_all(conf) ?? {})) {
		if (section['.type'] == type)
			push(rows, { sid: sid, section: section });
	}

	return rows;
}

function collect_values(fields, params, prefix, errors, values) {
	for (let f in fields) {
		if (f.type == 'file' || f.type == 'upload')
			continue;

		let key = field_key(f, prefix);
		let raw = params[key];

		if (type(raw) == 'object')
			continue;

		let value = null;

		if (f.type == 'flag') {
			value = truthy(raw) ? '1' : '0';
		}
		else if (f.type == 'list') {
			let items = [];

			for (let part in to_array(raw)) {
				if (part == null || type(part) == 'object')
					continue;

				for (let line in to_lines(part))
					push(items, line);
			}

			value = items;
		}
		else {
			value = trim_str(raw);
		}

		values[f.name] = value;

		let err = validate_value(f, value);

		if (err != null)
			errors[key] = err;
	}
}

function store_values(db, conf, sid, fields, values) {
	for (let f in fields) {
		if (f.type == 'file' || f.type == 'upload')
			continue;

		let value = values[f.name];

		if (f.type == 'flag') {
			db.set(conf, sid, f.name, truthy(value) ? '1' : '0');
			continue;
		}

		if (f.type == 'list') {
			let items = to_lines(value);

			if (!length(items))
				db.delete(conf, sid, f.name);
			else
				db.set(conf, sid, f.name, items);

			continue;
		}

		let str = value_of(value);

		if (!length(str))
			db.delete(conf, sid, f.name);
		else
			db.set(conf, sid, f.name, str);
	}
}

// ---------------------------------------------------------------------------
// Grid sections
// ---------------------------------------------------------------------------

function grid_has_new(block, values) {
	for (let f in block.fields) {
		if (f.type == 'flag' || f.type == 'file' || f.type == 'upload')
			continue;

		let v = values[f.name];

		if (type(v) == 'array' ? length(v) : length(value_of(v)))
			return true;
	}

	return false;
}

function render_grid(app, block, db, state) {
	let out = '';

	if (block.title != null)
		out += '<h3>' + esc(t(block.title)) + '</h3>';

	if (block.description != null)
		out += '<div class="cbi-section-descr">' + esc(t(block.description)) + '</div>';

	let rows = section_rows(db, app.conf, block.type);
	let index = 0;

	for (let row in rows) {
		index++;

		let sid = row.sid;
		let overlay = state.overlay['grid:' + block.type + ':' + sid];
		let values = overlay ?? row.section;
		let label = '';

		if (block.label_field != null)
			label = value_of(values[block.label_field]);

		let del_id = esc('del__' + sid);

		out += '<div class="cbi-section-node">';
		out += '<h4>' + (length(label) ? esc(label) : sprintf('#%d', index)) + '</h4>';
		out += render_fields(block.fields, values, state.errors, 'row__' + sid + '__');
		out += '<div class="cbi-value"><label class="cbi-value-title" for="' + del_id + '">' + esc(t('Delete')) + '</label>';
		out += '<div class="cbi-value-field"><input type="checkbox" id="' + del_id + '" name="' + del_id + '" value="1" />';
		out += ' <label for="' + del_id + '">' + esc(t('Delete this entry')) + '</label></div></div>';
		out += '</div>';
	}

	let fresh = state.overlay['grid:' + block.type + ':new'] ?? {};

	out += '<div class="cbi-section-node">';
	out += '<h4>' + esc(t(block.add_title ?? 'Add new entry')) + '</h4>';
	out += render_fields(block.fields, fresh, state.errors, 'new__');
	out += '</div>';

	return out;
}

function apply_grid(app, block, db, params, state) {
	for (let row in section_rows(db, app.conf, block.type)) {
		let sid = row.sid;

		if (truthy(params['del__' + sid])) {
			push(state.deletes, sid);
			continue;
		}

		let values = {};

		collect_values(block.fields, params, 'row__' + sid + '__', state.errors, values);
		state.overlay['grid:' + block.type + ':' + sid] = values;
		push(state.writes, { sid: sid, fields: block.fields, values: values });
	}

	let create = {};

	collect_values(block.fields, params, 'new__', state.errors, create);

	for (let key, value in (block.defaults ?? {})) {
		if (!has_value(create[key]))
			create[key] = value;
	}

	state.overlay['grid:' + block.type + ':new'] = create;

	if (grid_has_new(block, create))
		push(state.creates, { type: block.type, fields: block.fields, values: create });
}

// ---------------------------------------------------------------------------
// Plain files and uploads
// ---------------------------------------------------------------------------

function text_file_content(v) {
	let s = value_of(v);
	let n = length(s);

	while (n > 0) {
		let c = substr(s, n - 1, 1);

		if (c == chr(10) || c == chr(13) || c == chr(9) || c == ' ')
			n--;
		else
			break;
	}

	s = substr(s, 0, n);

	if (n)
		s += chr(10);

	return s;
}

function render_file_block(block, state) {
	let key = 'file__' + block.name;
	let content = state.overlay['file:' + block.name];

	if (content == null)
		content = readfile(block.path) ?? '';

	let out = '<div class="cbi-section">';

	if (block.title != null)
		out += '<h3>' + esc(t(block.title)) + '</h3>';

	if (block.description != null)
		out += '<div class="cbi-section-descr">' + esc(t(block.description)) + '</div>';

	out += '<textarea id="' + esc(key) + '" name="' + esc(key) + '" rows="' + (block.rows ?? 12) + '" cols="64" class="cbi-input-textarea" wrap="off" style="font-family:monospace;width:100%">' + esc(content) + '</textarea>';
	out += '</div>';

	return out;
}

function render_upload_block(block, state) {
	let key = 'upload__' + block.name;
	let out = '<div class="cbi-value"><label class="cbi-value-title" for="' + esc(key) + '">' + esc(t(block.title ?? 'Upload File')) + '</label>';
	out += '<div class="cbi-value-field"><input type="file" id="' + esc(key) + '" name="' + esc(key) + '" class="cbi-input-file" /></div></div>';

	if (state != null && state.errors[key] != null)
		out += '<div class="cbi-value-error" style="color:#c43c35">' + esc(t('File upload failed.')) + '</div>';

	if (block.description != null)
		out += '<div class="cbi-value-description">' + esc(t(block.description)) + '</div>';

	return out;
}

function save_upload(upload) {
	let field = upload.field;

	if (type(field) != 'object' || field.fd == null)
		return null;

	let name = basename(value_of(field.name));

	if (!length(name) || index(name, '..') >= 0)
		return null;

	let dir = upload.dir;

	if (stat(dir) == null)
		mkdir(dir, 493);

	let data = field.fd.read('all');

	if (data == null || !length(data))
		return null;

	let path = dir + '/' + name;

	if (writefile(path, data) == null)
		return null;

	return path;
}

// ---------------------------------------------------------------------------
// Applying a form
// ---------------------------------------------------------------------------

function apply_tab(app, tab, db, params, state) {
	for (let block in (tab.blocks ?? [])) {
		if (block.kind == 'fields') {
			let values = {};

			collect_values(block.fields, params, '', state.errors, values);

			if (type(app.validate) == 'function')
				app.validate(values, state, db);

			state.overlay.main = values;
			push(state.fieldsets, { fields: block.fields, values: values });
		}
		else if (block.kind == 'grid') {
			apply_grid(app, block, db, params, state);
		}
		else if (block.kind == 'file') {
			let content = text_file_content(params['file__' + block.name]);

			state.overlay['file:' + block.name] = content;
			push(state.files, { path: block.path, content: content });
		}
		else if (block.kind == 'upload') {
			let field = params['upload__' + block.name];

			if (type(field) == 'object' && field.fd != null) {
				let path = save_upload({ field: field, dir: block.dir });

				if (path == null) {
					state.errors['upload__' + block.name] = true;
					state.message = t('File upload failed.');
					state.message_kind = 'danger';
				}
				else {
					push(state.uploads, { path: path, option: block.option });
				}
			}
		}
	}
}

function commit_state(app, db, state) {
	if (length(state.fieldsets)) {
		let sid = ensure_section(db, app);

		for (let fs in state.fieldsets)
			store_values(db, app.conf, sid, fs.fields, fs.values);
	}

	for (let write in state.writes)
		store_values(db, app.conf, write.sid, write.fields, write.values);

	for (let sid in state.deletes)
		db.delete(app.conf, sid);

	for (let create in state.creates) {
		let sid = db.add(app.conf, create.type);

		store_values(db, app.conf, sid, create.fields, create.values);
	}

	for (let file in state.files)
		writefile(file.path, file.content);

	for (let upload in state.uploads) {
		if (upload.option != null) {
			let sid = ensure_section(db, app);

			db.set(app.conf, sid, upload.option, upload.path);
		}
	}

	return db.commit(app.conf) != null;
}

function run_command(cmd) {
	let proc = popen(cmd);

	if (proc == null)
		return { code: -1, out: '' };

	let out = proc.read('all') ?? '';
	let code = proc.close();

	return { code: code ?? 0, out: out };
}

function service_command(app, action) {
	return run_command('/etc/init.d/' + app.service + ' ' + action + ' 2>&1');
}

// ---------------------------------------------------------------------------
// Page rendering
// ---------------------------------------------------------------------------

function find_tab(app, id) {
	let want = value_of(id);

	for (let tab in app.tabs) {
		if (tab.id == want)
			return tab;
	}

	return null;
}

function tab_has_upload(tab) {
	for (let block in (tab.blocks ?? [])) {
		if (block.kind == 'upload')
			return true;
	}

	return false;
}

function render_tabs(app, tab, base) {
	let out = '<ul class="cbi-tabmenu">';

	for (let item in app.tabs) {
		let cls = (item.id == tab.id) ? 'active' : 'cbi-tab-disabled';

		out += '<li class="' + cls + '"><a href="' + esc(base + '?tab=' + item.id) + '">' + esc(t(item.title)) + '</a></li>';
	}

	out += '</ul>';

	return out;
}

function render_status(env, app, db) {
	let info = { running: false, warnings: [] };

	if (type(app.status) == 'function')
		info = app.status(env, db) ?? info;

	let out = '<div class="cbi-section">';

	if (info.running)
		out += '<span class="label success">' + esc(t('RUNNING')) + '</span> ';
	else
		out += '<span class="label important">' + esc(t('NOT RUNNING')) + '</span> ';

	out += '<strong>' + esc(t(info.legend ?? 'SmartDNS')) + ' - ' + esc(t(info.running ? 'RUNNING' : 'NOT RUNNING')) + '</strong>';

	if (info.webui != null)
		out += ' <a class="cbi-button cbi-button-action" target="_blank" rel="noreferrer" href="' + esc(info.webui) + '">' + esc(t('Open the WebUI')) + '</a>';

	out += '</div>';

	for (let warning in (info.warnings ?? []))
		out += '<div class="alert-message warning">' + esc(t(warning)) + '</div>';

	return out;
}

function render_blocks(env, app, tab, db, state) {
	let out = '';

	for (let block in (tab.blocks ?? [])) {
		if (block.kind == 'fields') {
			let values = state.overlay.main;

			if (values == null)
				values = read_section(db, app.conf, db.get_first(app.conf, app.section));

			out += '<div class="cbi-section">';

			if (block.title != null)
				out += '<h3>' + esc(t(block.title)) + '</h3>';

			if (block.description != null)
				out += '<div class="cbi-section-descr">' + esc(t(block.description)) + '</div>';

			out += render_fields(block.fields, values, state.errors, '');
			out += '</div>';
		}
		else if (block.kind == 'grid') {
			out += '<div class="cbi-section">' + render_grid(app, block, db, state) + '</div>';
		}
		else if (block.kind == 'file') {
			out += render_file_block(block, state);
		}
		else if (block.kind == 'upload') {
			out += render_upload_block(block, state);
		}
		else if (block.kind == 'links') {
			out += '<div class="cbi-section">';

			if (block.title != null)
				out += '<h3>' + esc(t(block.title)) + '</h3>';

			out += '<ul>';

			for (let link in (block.links ?? []))
				out += '<li><a href="' + esc(link.href) + '" target="_blank" rel="noreferrer">' + esc(t(link.title)) + '</a></li>';

			out += '</ul></div>';
		}
		else if (block.kind == 'html') {
			out += block.html ?? '';
		}
	}

	return out;
}

function render_actions(app, tab) {
	let out = '<div class="cbi-page-actions">';

	out += '<button type="submit" class="cbi-button cbi-button-apply" name="action" value="apply">' + esc(t('Apply')) + '</button>';

	if (app.actions != null && app.actions.restart)
		out += ' <button type="submit" class="cbi-button cbi-button-reload" name="action" value="restart">' + esc(t('Restart Service')) + '</button>';

	if (app.actions != null && app.actions.updatefiles)
		out += ' <button type="submit" class="cbi-button cbi-button-action" name="action" value="updatefiles">' + esc(t('Update Files')) + '</button>';

	out += '</div>';

	return out;
}

function depends_script() {
	let out = '<script type="text/javascript">';

	out += '(function(){';
	out += 'var nodes = document.querySelectorAll("[data-depends]");';
	out += 'function val(el){ return el.type === "checkbox" ? (el.checked ? "1" : "0") : el.value; }';
	out += 'function check(){';
	out += 'for (var i = 0; i < nodes.length; i++){';
	out += 'var node = nodes[i], deps = [], show = true;';
	out += 'try { deps = JSON.parse(node.getAttribute("data-depends")) || []; } catch (e) { deps = []; }';
	out += 'var groups = {};';
	out += 'for (var j = 0; j < deps.length; j++){';
	out += 'if (!groups[deps[j].field]) groups[deps[j].field] = [];';
	out += 'groups[deps[j].field].push(deps[j].value);';
	out += '}';
	out += 'for (var field in groups){';
	out += 'var el = document.getElementById(field);';
	out += 'if (!el) continue;';
	out += 'var cur = val(el), ok = false;';
	out += 'for (var k = 0; k < groups[field].length; k++) { if (groups[field][k] === cur) ok = true; }';
	out += 'if (!ok) show = false;';
	out += '}';
	out += 'node.style.display = show ? "" : "none";';
	out += '}';
	out += '}';
	out += 'check();';
	out += 'var all = document.querySelectorAll("input, select, textarea");';
	out += 'for (var n = 0; n < all.length; n++){';
	out += 'all[n].addEventListener("change", check);';
	out += 'all[n].addEventListener("input", check);';
	out += '}';
	out += '})();';
	out += '</script>';

	return out;
}

function render_page(env, app, db, tab, state) {
	let http = env.http;
	let base = env.dispatcher.build_url(app.base);
	let enctype = tab_has_upload(tab) ? ' enctype="multipart/form-data"' : '';
	let body = '';

	body += '<h2 name="content">' + esc(t(app.title)) + '</h2>';

	if (app.describe != null)
		body += '<div class="cbi-map-descr">' + esc(t(app.describe)) + '</div>';

	body += '<div class="cbi-map">';
	body += render_status(env, app, db);

	if (state.message != null)
		body += '<div class="alert-message ' + (state.message_kind ?? 'info') + '">' + esc(state.message) + '</div>';

	body += render_tabs(app, tab, base);
	body += '<form method="post" action="' + esc(base + '?tab=' + tab.id) + '"' + enctype + ' class="cbi-map">';
	body += '<input type="hidden" name="token" value="' + esc(env.ctx.authtoken) + '" />';
	body += '<input type="hidden" name="tab" value="' + esc(tab.id) + '" />';
	body += render_blocks(env, app, tab, db, state);
	body += render_actions(app, tab);
	body += '</form></div>';
	body += depends_script();

	env.include('header');
	http.write(body);
	env.include('footer');
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

export function dispatch(env, app) {
	translate = (s) => (type(env._) == 'function' ? env._(s) : s);

	let http = env.http;
	let db = env.uci;
	let state = {
		errors: {},
		overlay: {},
		fieldsets: [],
		writes: [],
		creates: [],
		deletes: [],
		files: [],
		uploads: [],
		message: null,
		message_kind: 'info'
	};

	let method = http.getenv('REQUEST_METHOD') ?? 'GET';
	let query = {};
	let qs = http.getenv('QUERY_STRING');

	if (qs != null && length(qs))
		query = http.urldecode_params(qs) ?? {};

	let tab = find_tab(app, query.tab);

	db.load(app.conf);

	if (type(app.setup) == 'function')
		app.setup(env, db, app);

	http.prepare_content('text/html; charset=UTF-8');

	if (method == 'POST') {
		let token = http.formvalue('token');

		if (type(token) != 'string' || token != env.ctx.authtoken) {
			http.status(403, 'Forbidden');
			http.write('<p>' + esc(t('Invalid token')) + '</p>');
			return;
		}

		let posted_tab = http.formvalue('tab');

		if (posted_tab != null)
			tab = find_tab(app, posted_tab);

		if (tab == null) {
			http.status(400, 'Bad Request');
			http.write('<p>' + esc(t('Invalid tab')) + '</p>');
			return;
		}

		let params = http.formvalue() ?? {};
		let action = value_of(params.action);

		if (action == 'apply') {
			apply_tab(app, tab, db, params, state);

			if (length(keys(state.errors))) {
				if (state.message == null) {
					state.message = t('Some fields are invalid, please check the highlighted entries.');
					state.message_kind = 'danger';
				}
			}
			else if (!commit_state(app, db, state)) {
				state.message = t('Failed to save the configuration.');
				state.message_kind = 'danger';
			}
			else {
				service_command(app, 'reload');
				http.redirect(env.dispatcher.build_url(app.base) + '?tab=' + tab.id + '&saved=1');
				return;
			}
		}
		else if (action == 'restart') {
			let res = service_command(app, 'restart');

			state.message = sprintf('%s %s', t('Service restarted:'), trim_str(res.out));
			state.message_kind = 'info';
		}
		else if (action == 'updatefiles') {
			let res = service_command(app, 'updatefiles');

			state.message = sprintf('%s %s', t('Files updated:'), trim_str(res.out));
			state.message_kind = 'info';
		}
	}
	else {
		if (tab == null)
			tab = app.tabs[0];

		if (truthy(query.saved)) {
			state.message = t('Configuration has been applied.');
			state.message_kind = 'success';
		}
	}

	render_page(env, app, db, tab, state);
}

