// SPDX-License-Identifier: GPL-3.0-or-later
// LuCI controller of luci-app-smartdns-lite (ucode).

import { dispatch } from 'luci.model.smartdns_lite.form';
import { app } from 'luci.model.smartdns_lite.schema';

return {
	index: function(env) {
		dispatch(env, app);
	}
};
