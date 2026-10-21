# XY-C1 固件定制开发笔记

记录本次对小娱 XY-C1 Padavan 固件的裁剪、RouteFlow 重写过程，以及过程中踩过的坑。
供后续维护参考。

---

## 一、总体目标

在 [hanwckf/rt-n56u](https://github.com/hanwckf/rt-n56u) 基础上，产出一份**只包含基本路由、IPv6、国内外分流**的固件：

- 关闭 USB（用户态 + 内核态）
- 关闭 SSH / SFTP / curl
- 移除软件中心（SoftCenter）
- 移除其余第三方插件
- 默认 LAN IP 改为 `192.168.0.1`
- 把国内外分流（RouteFlow）直接集成进固件

---

## 二、组件裁剪

### 2.1 编译开关与内核配置必须同时处理

Padavan 的 `CONFIG_FIRMWARE_*` 只控制**用户态**编译，不会自动关闭内核里的驱动。
例如只设 `CONFIG_FIRMWARE_ENABLE_USB=n`，内核里 `CONFIG_USB_SUPPORT` 仍然会把
USB / ATA / SCSI 一整套编进去，固件体积和启动耗时都会受影响。

正确做法：

1. 在 `trunk/configs/templates/XY-C1.config` 里关掉 `CONFIG_FIRMWARE_ENABLE_USB`
2. 在 `trunk/configs/boards/XY-C1/kernel-3.4.x.config` 里同时关闭依赖链：

```
CONFIG_USB_SUPPORT → CONFIG_USB → CONFIG_USB_STORAGE
                   → CONFIG_BLK_DEV_SD → CONFIG_SCSI → CONFIG_ATA
```

因为 `CONFIG_BLK_DEV_SD` 存在时，`trunk/user/Makefile` 和
`trunk/libs/Makefile` 里的 `STORAGE_ENABLED` 会被自动置为 `y`，
进而编译 libdisk / aidisk 等一整串存储相关组件。

### 2.2 页面文件的清理依赖 Makefile

`trunk/user/www/Makefile` 里有一组反向规则：当某个插件开关为 `n` 时，
从 romfs 里删掉对应页面。新增插件页面时记得同步加一条，否则页面对用户不可见。

### 2.3 默认 LAN IP 的覆盖方式

`trunk/user/shared/defaults.h` 中的 `DEF_LAN_ADDR` / `DEF_LAN_DHCP_BEG` /
`DEF_LAN_DHCP_END` 会被 `defaults.c` 的 nvram 默认值表引用。
仅改 nvram 默认值不够（老设备 nvram 里已有旧值不会覆盖），

最终做法是在 `trunk/user/shared/cflags.mk` 里做**编译期宏重定义**：

```make
ifneq ($(CONFIG_FIRMWARE_LAN_IP),)
CFLAGS += -DDEF_LAN_ADDR=\"$(CONFIG_FIRMWARE_LAN_IP)\"
endif
ifneq ($(CONFIG_FIRMWARE_LAN_IP_BEG),)
CFLAGS += -DDEF_LAN_DHCP_BEG=\"$(CONFIG_FIRMWARE_LAN_IP_BEG)\"
endif
ifneq ($(CONFIG_FIRMWARE_LAN_IP_END),)
CFLAGS += -DDEF_LAN_DHCP_END=\"$(CONFIG_FIRMWARE_LAN_IP_END)\"
endif
```

配合 `XY-C1.config` 里的 `CONFIG_FIRMWARE_LAN_IP` 等变量即可。

---

## 三、RouteFlow 页面重构

### 3.1 旧实现的两个致命问题

**问题 1：保存卡死 / 列表只显示一部分**

旧页面用一个 `<textarea>` 装载**整个** GWF 列表，点「保存列表」时一次性 POST。
6195 行的列表约 100 KB，而 `trunk/user/httpd/web_ex.c` 里：

```c
static char post_buf[32768] = {0};
```

POST 体在 `do_html_apply_post()` 中被 `fgets()` 读进这个 32 KB 的固定缓冲区，
超出部分被**静默丢弃**。这就是「上传 6195 条只显示 1731 条」的根因，
同时也是大表单提交后页面卡死的来源。

**问题 2：大列表无法增量维护**

textarea 方案要求用户一次提交全量数据，任何一条增删都要重传整个列表。

### 3.2 新实现：单条增量操作

彻底放弃「整表提交」，改为对文件的**单条增删改**：

| 动作 | 后端处理 |
| --- | --- |
| add | 追加一行（先查重、trim） |
| edit | 读原文件 → 写临时文件（替换目标行）→ rename |
| delete | 读原文件 → 写临时文件（跳过目标行）→ rename |

优点：

- POST 体只有几十字节，完全绕开 32 KB 缓冲区限制
- 每次操作只触碰一行，6195 条也能秒开
- 临时文件 + `rename()` 保证原子性，写一半掉电不会毁列表

大列表的初次导入仍保留**文件上传**通道（`multipart/form-data` 流式写入，
不走 `post_buf`），已在主机侧用 6195 条数据验证：写入 6195 行、无边界残留。

### 3.3 UI 结构

页面只保留两个选项卡，用 Bootstrap `nav-tabs` 手写：

- **一般设置**：开关、旁路由网关、DNS 防污染
- **GWF 域名列表**：添加 / 搜索 / 列表（可编辑、可删除）/ 上传文件

默认**不加载任何列表数据**，必须输入关键词点「搜索」才显示结果。
后端 `routeflow_gfw_rows_hook` 在既无 `keyword` 也无 `all=1` 时直接输出空数组。

操作确认后自动执行：

```c
doSystem("/sbin/mtd_storage.sh save >/dev/null 2>&1 &");
notify_rc(RCN_RESTART_ROUTEFLOW);
```

即「点确认 → 自动保存 → 自动重启服务」，不再需要「保存列表」「重启服务」按钮。

---

## 四、调试过程中踩过的坑

### 4.1 ASP 钩子输出 JavaScript 必须自己带 `<script>` 标签

`routeflow_action.asp` 的结构是：

```html
<body onLoad="Callback();">
<% routeflow_action(); %>
<form method="post" name="redirectForm" action="/routeflow.asp" target="_self"></form>
</body>
```

`<% ... %>` 在 `<script>` **之外**。如果钩子里直接写：

```c
websWrite(wp, "parent.location.href=\"/routeflow.asp\";\n");
```

浏览器会把这段当成**纯文本**渲染，脚本根本不执行，页面就永远停在
「正在处理」的遮罩上。

正确写法（钩子自己补 `<script>`）：

```c
websWrite(wp, "<script>parent.location.href=\"/routeflow.asp?rtf_tab=gfw&keyword=");
rtf_url_encode(wp, kw);
websWrite(wp, "\";</script>\n");
```

### 4.2 页面模板必须包含 `#tabMenu`，否则 `show_menu` 抛异常

这是最隐蔽的一个 bug。Padavan 的 `state.js` 中 `show_menu(L1, L2, L3)`：

```js
if(L3){
    ...
    $("tabMenu").innerHTML = tab_code;
}
else
    $("tabMenu").innerHTML = "";
```

**无论 L3 是否为真，都会访问 `$("tabMenu")`**。如果页面里没有这个节点，
`$("tabMenu")` 返回 `null`，赋值时抛 `TypeError`。

后果非常迷惑人——因为 `show_menu()` 通常是 `initial()` 的第一行：

```js
function initial(){
    show_banner(2);
    show_menu(5,15,1);          // ← 在这里抛异常
    show_footer();
    fill_status(routeflow_status());
    $("routeflow_gfw_count").innerHTML = routeflow_gfw_count();  // ← 不会执行
    renderRows();                                                // ← 不会执行
    ...
}
```

表现就是：

- 「当前域名数量」永远显示 HTML 里的初始值 `0`
- 列表永远是空的
- 选项卡永远不会切到 GWF
- 无论添加/上传/搜索，看起来都像「数据没写进去」

**排查方法**：逐个对比同目录下能正常工作的插件页，检查它们都有哪些 DOM 节点。
本次就是对比 `Shadowsocks.asp` / `softcenter.asp` 发现少了 `#tabMenu`。

**结论**：自定义页面时，`show_banner` / `show_menu` / `show_footer` 依赖的
DOM 节点必须齐全，包括：

```html
<div id="TopBanner"></div>
<div id="mainMenu"></div>
<div id="subMenu"></div>
<div id="tabMenu" class="submenuBlock"></div>
<div id="footer"></div>
<div id="Loading" class="popup_bg"></div>
```

### 4.3 自定义选项卡与 `show_menu` 的 L3 栏会重复

如果页面自己用 `nav-tabs` 做了选项卡，再调 `show_menu(5, 15, 1)`，
`show_menu` 会额外渲染一条 Level-3 子选项卡栏，出现**两个「一般设置」**。

解法：L3 传 `0`，让它走 `else` 分支写入空字符串（因此 `#tabMenu` 节点仍需保留）：

```js
show_menu(5,15,0);
```

### 4.4 修改源码后要确认改动真的进了二进制

`build_firmware_modify` 走的是增量编译。若在构建**启动之后**又改了源码，
当次产物不会包含该改动。验证方式：

```shell
strings trunk/romfs/usr/sbin/httpd | grep -F 'rtf_tab=gfw'
```

确认字符串存在，再确认 `trunk/user/httpd/web_ex.o` 的 mtime 晚于源码。

### 4.5 上传后要跳回正确的选项卡

上传成功却「看起来没生效」，常见原因是跳回了默认选项卡，而列表默认不显示数据。
处理办法是让上传完成后的重定向带上选项卡与预览参数：

```c
"<script>parent.location.href='/routeflow.asp?rtf_tab=gfw&all=1';</script>"
```

`all=1` 时后端输出前 1000 条作为预览；正常进入页面仍保持空列表。

---

## 五、构建环境相关问题

### 5.1 宿主机依赖

```shell
apt-get install -y gettext autopoint libtool autoconf automake \
                   flex bison gperf texinfo kmod
```

其中 `depmod` 容易被忽略：构建内核模块时依赖它，且路径需为 `/sbin/depmod`。

### 5.2 autotools 时间戳问题

`tools/mksquashfs_xz/xz-5.2.4` 等包在 `autogen.sh` 后会重新生成
`configure` / `Makefile.in` / `aclocal.m4`。如果宿主机时钟或文件时间不一致，
会报：

```
configure: error: newly created file is older than distributed files!
Check your system clock
```

排查与处理：

1. 先确认系统时间正确
2. 找出所有**未来时间**的文件：
   ```shell
   find . -newermt "tomorrow" -type f
   ```
3. 把这些 autotools 生成文件统一 touch 到一个**早于当前、晚于源文件**的时间：
   ```shell
   find . -newermt "tomorrow" -print0 | xargs -0 touch -d "now"
   ```
   注意**不要** touch 到未来时间，否则 configure 的版本校验会反过来报错。

### 5.3 旧目标文件残留

切换配置（尤其是关闭 HTTPS / USB）后，如果 `user/` 下残留旧的
`httpd.o` / `https.o` / `aidisk.o`，链接会失败。处理：

```shell
find trunk/user -name '*.o' -type f -delete
```

### 5.4 交叉工具链

```shell
cd toolchain-mipsel && ./dl_toolchain.sh
```

脚本会下载 `mipsel-linux-uclibc.tar.xz` 并解压到 `toolchain-3.4.x/`。
构建脚本通过 `trunk/toolchain.inc` 里的 `CONFIG_TOOLCHAIN_DIR` 定位它。

---

## 六、涉及的主要文件

| 文件 | 作用 |
| --- | --- |
| `trunk/configs/templates/XY-C1.config` | 机型编译开关（功能裁剪总入口） |
| `trunk/configs/boards/XY-C1/kernel-3.4.x.config` | 内核裁剪（USB/ATA/SCSI） |
| `trunk/user/shared/cflags.mk` | 把开关转成 `-DAPP_*` 宏；默认 LAN IP 覆盖 |
| `trunk/user/shared/defaults.h` / `defaults.c` | nvram 默认值 |
| `trunk/user/httpd/web_ex.c` | RouteFlow 后端钩子（add/edit/delete/搜索/状态） |
| `trunk/user/httpd/upload.c` | GWF 文件流式上传 |
| `trunk/user/routeflow/routeflow.sh` | 分流主逻辑（ipset + iptables + dnsmasq） |
| `trunk/user/www/n56u_ribbon_fixed/routeflow.asp` | 双选项卡前端页面 |
| `trunk/user/www/dict/CN.dict` / `EN.footer` | 中英文词条 |
| `trunk/user/www/n56u_ribbon_fixed/state.js` | 菜单与选项卡注册 |

---

## 七、验证清单

改完 RouteFlow 相关代码后，建议按以下顺序自测：

1. 页面能正常打开，只有一个选项卡栏，无重复「一般设置」
2. 默认进入时「当前域名数量」显示真实条数（不是固定 0）
3. 添加一个域名 → 确认 → 自动跳回 GWF 选项卡并能搜到该域名
4. 修改该域名 → 确认 → 列表显示新值
5. 删除该域名 → 确认 → 列表中消失
6. 上传一个数千行的纯文本列表 → 数量正确、预览正常
7. `logread` 中能看到 `Storage save` 与 routeflow 重启日志
8. 重启设备后列表仍在（已被 `mtd_storage.sh save` 持久化）
