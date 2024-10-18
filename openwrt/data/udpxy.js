'use strict';
'require form';
'require view';

return view.extend({
	render: function () {
		var m, s, o;

		m = new form.Map('udpxy', _('udpxy'),
			_('udpxy是UDP到HTTP的多播流量中继守护程序，您可以在此处配置设置。'));

		s = m.section(form.TypedSection, 'udpxy');
		s.anonymous = true;
		s.addremove = true;

		o = s.option(form.Flag, 'disabled', _('启用'));
		o.enabled = '0';
		o.disabled = '1';
		o.default = o.disabled;
		o.rmempty = false;

		o = s.option(form.Flag, 'respawn', _('复位'));
		o.default = o.disabled;

		o = s.option(form.Flag, 'verbose', _('详细'));
		o.default = o.disabled;

		o = s.option(form.Flag, 'status', _('状态'));

		o = s.option(form.Value, 'bind', _('绑定IP/接口'));
		o.datatype = 'or(ipaddr, network)';

		o = s.option(form.Value, 'port', _('端口'));
		o.datatype = 'port';

		o = s.option(form.Value, 'source', _('源IP/接口'));
		o.datatype = 'or(ipaddr, network)';

		o = s.option(form.Value, 'max_clients', _('最大客户数'));
		o.datatype = 'range(1, 5000)';

		o = s.option(form.Value, 'log_file', _('日志文件'));

		o = s.option(form.Value, 'buffer_size', _('缓冲区大小'));
		o.datatype = 'range(4096, 2097152)';

		o = s.option(form.Value, 'buffer_messages', _('缓冲信息'));
		o.datatype = 'or(-1, and(min(1),uinteger))';

		o = s.option(form.Value, 'buffer_time', _('缓冲时间'));
		o.datatype = 'or(-1, and(min(1),uinteger))';

		o = s.option(form.Value, 'nice_increment', _('增量'));
		o.datatype = 'or(and(max(-1),uinteger), and(min(1),uinteger))';

		o = s.option(form.Value, 'mcsub_renew', _('组播订阅续订'));
		o.datatype = 'or(0, range(30, 64000))';

		return m.render();
	}
});
