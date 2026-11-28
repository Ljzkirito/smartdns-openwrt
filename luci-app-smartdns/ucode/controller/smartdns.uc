// SPDX-License-Identifier: GPL-3.0-or-later
// LuCI controller of luci-app-smartdns (ucode).

import { dispatch } from 'luci.model.smartdns.form';
import { app } from 'luci.model.smartdns.schema';

return {
	index: function(env) {
		dispatch(env, app);
	}
};
