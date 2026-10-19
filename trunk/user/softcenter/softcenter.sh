#!/bin/sh
#
# 软件中心 (SoftCenter) - 插件包(.pak) 安装 / 卸载 / 启停
#
# .pak 是 gzip 压缩的 tar 包(tar.gz)，包根目录下的文件会被安装到
# /etc/storage/softcenter/plugins/<name>/ 。其中：
#   control       必需，插件元数据，key=value 文本，至少包含：
#                 name=<插件名>   version=<版本>   description=<描述>
#   install.sh    可选，安装后执行（工作目录为插件目录）
#   uninstall.sh  可选，卸载前执行
#   start.sh      可选，开机 / 启用时执行
#   stop.sh       可选，停用时执行
# 其余任意文件随包一起安装。
#
# 已安装插件列表保存在 nvram 变量 softcenter_list（空格分隔）。
#

SC_ROOT="/etc/storage/softcenter"
SC_DIR="$SC_ROOT/plugins"
SC_NV="softcenter_list"
SC_LOG="/tmp/softcenter.log"
SC_MAX_SIZE=16777216		# .pak 最大 16MB

log() {
	logger -st softcenter "$1"
}

# 插件名校验：字母或数字开头，仅含字母/数字/下划线/点/短横线
valid_name() {
	[ -n "$1" ] || return 1
	echo "$1" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9_.-]*$'
}

# 从 control 文件读取 key（$2）对应的值
ctl_get() {
	[ -f "$1" ] || return 1
	grep -m1 "^$2=" "$1" 2>/dev/null | cut -d= -f2- | tr -d '\r'
}

plugin_dir() {
	echo "$SC_DIR/$1"
}

# 把插件名加入 nvram 列表
list_add() {
	local name="$1" list
	list="$(nvram get "$SC_NV")"
	case " $list " in
		*" $name "*) return 0 ;;
	esac
	list="${list:+$list }$name"
	nvram set "$SC_NV=$list"
	nvram commit
}

# 从 nvram 列表移除插件名
list_del() {
	local name="$1" list out n
	list="$(nvram get "$SC_NV")"
	out=""
	for n in $list; do
		[ "$n" = "$name" ] && continue
		out="${out:+$out }$n"
	done
	nvram set "$SC_NV=$out"
	nvram commit
}

save_storage() {
	/sbin/mtd_storage.sh save >/dev/null 2>&1 &
}

# 执行插件内的钩子脚本（若存在且可执行）
run_hook() {
	local name="$1" script="$2" phase="$3" d
	d="$(plugin_dir "$name")"
	[ -x "$d/$script" ] || return 0
	log "$name: $phase -> $script"
	( cd "$d" && PLUGIN_NAME="$name" PLUGIN_DIR="$d" PLUGIN_PHASE="$phase" ./"$script" ) >>"$SC_LOG" 2>&1
}

start_plugin() {
	run_hook "$1" "start.sh" "start"
}

stop_plugin() {
	run_hook "$1" "stop.sh" "stop"
}

start_all() {
	local n
	for n in $(nvram get "$SC_NV"); do
		start_plugin "$n"
	done
}

stop_all() {
	local n
	for n in $(nvram get "$SC_NV"); do
		stop_plugin "$n"
	done
}

# 校验 .pak 是否为 gzip 压缩包
is_gzip() {
	[ "$(dd if="$1" bs=1 count=2 2>/dev/null | od -An -tx1 | tr -d ' \n')" = "1f8b" ]
}

do_install() {
	local pak="$1" work name ver dst sz

	: >"$SC_LOG"

	[ -f "$pak" ] || { echo "错误：找不到上传的插件包"; return 1; }

	sz="$(wc -c <"$pak" 2>/dev/null)"
	[ -n "$sz" ] && [ "$sz" -le "$SC_MAX_SIZE" ] || { echo "错误：插件包过大（上限 16MB）"; return 1; }

	is_gzip "$pak" || { echo "错误：不是有效的 .pak 插件包"; return 1; }

	work="/tmp/softcenter_work"
	rm -rf "$work"
	mkdir -p "$work" || { echo "错误：无法创建工作目录"; return 1; }

	# 拒绝绝对路径与目录穿越
	if tar tzf "$pak" 2>/dev/null | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
		echo "错误：插件包包含非法路径"
		rm -rf "$work"
		return 1
	fi

	tar xzf "$pak" -C "$work" 2>>"$SC_LOG" || { echo "错误：解压失败（插件包已损坏）"; rm -rf "$work"; return 1; }

	[ -f "$work/control" ] || { echo "错误：缺少 control 元数据文件"; rm -rf "$work"; return 1; }

	name="$(ctl_get "$work/control" name)"
	ver="$(ctl_get "$work/control" version)"

	valid_name "$name" || { echo "错误：control 中的 name 字段缺失或非法"; rm -rf "$work"; return 1; }

	dst="$(plugin_dir "$name")"
	[ -e "$dst" ] && { echo "错误：插件 $name 已安装，请先卸载"; rm -rf "$work"; return 1; }

	mkdir -p "$SC_DIR"
	mv "$work" "$dst" || { echo "错误：安装文件失败（存储空间不足？）"; rm -rf "$work"; return 1; }
	chmod 755 "$dst"/*.sh 2>/dev/null

	run_hook "$name" "install.sh" "install"
	list_add "$name"
	start_plugin "$name"
	save_storage

	log "installed: $name $ver"
	echo "安装成功：$name ${ver:+($ver)}"
	return 0
}

do_remove() {
	local name="$1" dst

	: >"$SC_LOG"

	valid_name "$name" || { echo "错误：插件名非法"; return 1; }

	dst="$(plugin_dir "$name")"
	[ -e "$dst" ] || { echo "错误：插件 $name 未安装"; return 1; }

	stop_plugin "$name"
	run_hook "$name" "uninstall.sh" "uninstall"
	rm -rf "$dst"
	list_del "$name"
	save_storage

	log "removed: $name"
	echo "卸载成功：$name"
	return 0
}

# 供调试：输出已安装插件 name|version|description
do_list() {
	local n d
	for n in $(nvram get "$SC_NV"); do
		d="$(plugin_dir "$n")"
		if [ -f "$d/control" ]; then
			echo "$n|$(ctl_get "$d/control" version)|$(ctl_get "$d/control" description)"
		else
			echo "$n||"
		fi
	done
}

case "$1" in
	start)
		start_all
		;;
	stop)
		stop_all
		;;
	restart)
		stop_all
		start_all
		;;
	install)
		do_install "$2"
		;;
	remove)
		do_remove "$2"
		;;
	list)
		do_list
		;;
	*)
		echo "Usage: $0 { start | stop | restart | install <pak> | remove <name> | list }"
		exit 1
		;;
esac
