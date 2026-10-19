#!/bin/sh
#
# RouteFlow - 国内外流量分流 + DNS 防污染
#
# 国内流量走 WAN 口，国外(GWF 列表中的域名)流量走指定的内网旁路由。
# DNS 防污染：为 GWF 列表中的域名指定干净的境外上游 DNS。
#
# 依赖：ipset / iptables / ip(iproute2) / 带 gfwlist 补丁的 dnsmasq
#

RF_DIR="/etc/storage/routeflow"
GFW_LIST="$RF_DIR/gfwlist.txt"
DEF_LIST="/etc_ro/routeflow/gfwlist.txt"
NORM_LIST="/tmp/routeflow/gfwlist.norm.txt"
DNSMASQ_CONF="/etc/storage/dnsmasq/dnsmasq.conf"
IPSET="rf_gfw"
MARK="0x40"
TABLE="100"
RUN_FLAG="/tmp/routeflow.run"

log() {
	logger -st routeflow "$1"
}

dns_running() {
	[ -n "$(pidof dnsmasq)" ]
}

load_modules() {
	modprobe ip_set 2>/dev/null
	modprobe ip_set_hash_ip 2>/dev/null
	modprobe xt_set 2>/dev/null
}

# 首次使用时用出厂默认列表初始化
seed_list() {
	[ -f "$GFW_LIST" ] && return 0
	mkdir -p "$RF_DIR" 2>/dev/null
	if [ -f "$DEF_LIST" ]; then
		cp -f "$DEF_LIST" "$GFW_LIST"
	else
		: > "$GFW_LIST"
	fi
}

# 把用户列表规范化为“每行一个域名”，兼容空格/逗号/换行分隔
normalize_list() {
	mkdir -p "$(dirname "$NORM_LIST")" 2>/dev/null
	tr ', \t' '\n\n\n' < "$GFW_LIST" 2>/dev/null | \
	awk '
		{
			sub(/\r$/, "")
			d = tolower($0)
			gsub(/^[ \t]+/, "", d)
			gsub(/[ \t]+$/, "", d)
			sub(/^\*\./, "", d)
			sub(/^\./, "", d)
			if (d == "" || d ~ /^#/) next
			print d
		}
	' > "$NORM_LIST"
}

# 生成 dnsmasq 片段：域名加入 ipset + 指定防污染上游
gen_dns_block() {
	local dns="$1"
	local tmp="/tmp/routeflow_dnsmasq.tmp"

	{
		echo "# ROUTEFLOW_BEGIN"
		if [ -n "$dns" ]; then
			# 使用 dnsmasq 原生 gfwlist 指令：命中域名加入 rf_gfw 集合，
			# 并由指定的防污染服务器解析。
			echo "gfwlist=$NORM_LIST@$dns^$IPSET"
		else
			# 仅做 ipset 归属，不改动上游 DNS
			awk -v set="$IPSET" '
				BEGIN { buf = ""; n = 0 }
				{
					if ($0 == "") next
					buf = buf "/" $0
					n++
					if (n >= 16) {
						printf "ipset=%s/%s\n", buf, set
						buf = ""; n = 0
					}
				}
				END { if (n > 0) printf "ipset=%s/%s\n", buf, set }
			' "$NORM_LIST"
		fi
		echo "# ROUTEFLOW_END"
	} > "$tmp"

	remove_dns_block
	cat "$tmp" >> "$DNSMASQ_CONF"
	rm -f "$tmp"
}

remove_dns_block() {
	[ -f "$DNSMASQ_CONF" ] || return 0
	grep -q "ROUTEFLOW_BEGIN" "$DNSMASQ_CONF" 2>/dev/null || return 0
	sed -i '/# ROUTEFLOW_BEGIN/,/# ROUTEFLOW_END/d' "$DNSMASQ_CONF"
}

# 建立 ipset 集合 + 策略路由 + mangle 标记
setup_route() {
	local gw="$1"

	ipset -! create "$IPSET" hash:ip hashsize 4096 maxelem 131072
	ipset flush "$IPSET"

	iptables -t mangle -D PREROUTING -j ROUTEFLOW 2>/dev/null
	iptables -t mangle -D OUTPUT -j ROUTEFLOW 2>/dev/null
	iptables -t mangle -F ROUTEFLOW 2>/dev/null
	iptables -t mangle -X ROUTEFLOW 2>/dev/null
	iptables -t mangle -N ROUTEFLOW
	iptables -t mangle -A ROUTEFLOW -m set --match-set "$IPSET" dst -j MARK --set-mark "$MARK"

	ip rule del fwmark "$MARK" lookup "$TABLE" 2>/dev/null
	ip route flush table "$TABLE" 2>/dev/null
	ip route add default via "$gw" dev "br0" table "$TABLE" 2>/dev/null || \
		ip route add default via "$gw" table "$TABLE"
	ip rule add fwmark "$MARK" lookup "$TABLE"

	iptables -t mangle -A PREROUTING -j ROUTEFLOW
	iptables -t mangle -A OUTPUT -j ROUTEFLOW
}

teardown_route() {
	iptables -t mangle -D PREROUTING -j ROUTEFLOW 2>/dev/null
	iptables -t mangle -D OUTPUT -j ROUTEFLOW 2>/dev/null
	iptables -t mangle -F ROUTEFLOW 2>/dev/null
	iptables -t mangle -X ROUTEFLOW 2>/dev/null

	ip rule del fwmark "$MARK" lookup "$TABLE" 2>/dev/null
	ip route flush table "$TABLE" 2>/dev/null

	ipset flush "$IPSET" 2>/dev/null
	ipset destroy "$IPSET" 2>/dev/null
}

func_start() {
	[ "$(nvram get routeflow_enable)" = "1" ] || { func_stop; return 0; }

	local gw
	gw="$(nvram get routeflow_gateway)"
	if [ -z "$gw" ]; then
		log "side-router address is empty, not started"
		return 1
	fi

	local dns=""
	if [ "$(nvram get routeflow_dns_enable)" = "1" ]; then
		dns="$(nvram get routeflow_dns | awk '{print $1}')"
		# 规范化端口分隔符：ip:port -> ip#port
		dns="$(echo "$dns" | tr ':' '#')"
	fi

	load_modules
	seed_list
	normalize_list
	gen_dns_block "$dns"
	setup_route "$gw"
	touch "$RUN_FLAG"
	dns_running && restart_dhcpd
	log "started (gateway=$gw, dns=$dns)"
}

func_stop() {
	teardown_route
	remove_dns_block
	rm -f "$RUN_FLAG"
	dns_running && restart_dhcpd
	log "stopped"
}

case "$1" in
start)
	func_start
	;;
stop)
	func_stop
	;;
restart)
	func_stop
	func_start
	;;
*)
	echo "Usage: $0 { start | stop | restart }"
	exit 1
	;;
esac
