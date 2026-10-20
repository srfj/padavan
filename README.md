# XY-C1 Padavan 固件（基本路由 + IPv6 + 国内外分流）

面向 **小娱 XY-C1（MT7621）** 的 Padavan 固件，基于 [hanwckf/rt-n56u](https://github.com/hanwckf/rt-n56u) 精简定制。

固件只做三件事：**基本路由**、**IPv6**、**国内外流量分流（RouteFlow）**。
第三方插件、软件中心、USB、SSH、curl 等全部移除，保持固件精简、稳定、可控。

---

## 功能特性

| 项目 | 说明 |
| --- | --- |
| 基本路由 | WAN/LAN、DHCP、NAT、防火墙、端口转发等原生功能 |
| IPv6 | 原生 IPv6 与 DHCPv6 支持 |
| 国内外分流 | RouteFlow：GWF 域名走旁路由，国内流量直连 |
| DNS 防污染 | 为 GWF 域名指定干净的境外上游 DNS |
| 默认管理地址 | `http://192.168.0.1` |
| DHCP 地址池 | `192.168.0.100 - 192.168.0.244` |

### 已移除的组件

- 软件中心（SoftCenter）及其 `.pak` 插件体系
- SSH（Dropbear / OpenSSH）与 SFTP
- curl
- USB 相关功能（内核层面同步关闭 USB / ATA / SCSI）
- 其余第三方插件（Shadowsocks、Transmission、Aria2、Samba、OpenVPN 等）

---

## RouteFlow 国内外分流

菜单路径：**高级设置 → 国内外分流**

### 一般设置

| 选项 | 说明 |
| --- | --- |
| 启用国内外分流 | 总开关 |
| 旁路由网关（国外流量） | 承载国外流量的内网旁路由地址 |
| 启用 DNS 防污染 | 为 GWF 域名指定干净上游 |
| 防污染 DNS 服务器 | 例如 `8.8.8.8` 或 `8.8.8.8:53` |

### GWF 域名列表

同一页面下的第二个选项卡，默认不展示数据，需主动操作：

- **添加域名**：输入框输入域名 → 点击「添加域名」→ 确认后自动写入、保存并重启服务
- **搜索**：输入关键词 → 点击「搜索」→ 模糊匹配展示结果（不区分大小写）
- **修改 / 删除**：每条结果支持独立编辑与删除，确认后自动保存并重启服务
- **上传 GWF 文件**：从本地选择纯文本列表上传覆盖（适合数千条的大列表）

> 列表存储于 `/etc/storage/routeflow/gfwlist.txt`；首次启动会从 `/etc_ro/routeflow/gfwlist.txt` 初始化。

### 工作原理

1. `routeflow.sh` 将列表规范化为「每行一个域名」
2. 生成 dnsmasq 片段：命中域名加入 ipset `rf_gfw`，并由指定上游解析
3. iptables mangle 表按 ipset 打标记，配合独立路由表把流量送到旁路由

---

## 编译

### 环境依赖

```shell
sudo apt-get update
sudo apt-get install -y gettext autopoint libtool autoconf automake \
     flex bison gperf texinfo kmod bzip2 xz-utils
```

### 获取交叉工具链

```shell
cd toolchain-mipsel
./dl_toolchain.sh
```

### 构建

```shell
cd trunk
./build_firmware_modify XY-C1
```

产物：`trunk/images/XY-C1_3.4.3.9-099.trx`

### 机型配置

编译选项集中在 [`trunk/configs/templates/XY-C1.config`](trunk/configs/templates/XY-C1.config)，
内核选项在 [`trunk/configs/boards/XY-C1/kernel-3.4.x.config`](trunk/configs/boards/XY-C1/kernel-3.4.x.config)。

---

## 刷机

1. 进入原厂 / 现有固件的升级页面，选择 `XY-C1_3.4.3.9-099.trx`
2. 等待重启完成（约 2 分钟）
3. 浏览器访问 `http://192.168.0.1`
4. 建议刷机后执行一次恢复出厂设置

> 刷机有风险，请自行评估。变砖需自行用编程器 / Breed 恢复。

---

## 开发与修改记录

本次定制的完整改动说明、踩坑记录与调试经验见：

**[docs/development-notes.md](docs/development-notes.md)**

涵盖：

- 如何裁剪组件（编译开关 + 内核配置双管齐下）
- 默认 LAN IP 的编译期覆盖方式
- RouteFlow 页面从 textarea 全量提交改为单条增量操作的原因
- Padavan `httpd` 的 POST 缓冲区限制与规避
- ASP 钩子输出 JavaScript 的正确方式
- Padavan 页面模板必须包含的 DOM 节点（否则 `show_menu` 抛异常）
- 构建环境相关的 autotools / 时间戳问题

---

## 目录结构

```
├── trunk/                     # 主源码树
│   ├── configs/
│   │   ├── templates/         # 机型编译配置（XY-C1.config）
│   │   └── boards/            # 机型板级与内核配置
│   ├── user/
│   │   ├── httpd/             # Web 服务（web_ex.c 含 RouteFlow 钩子）
│   │   ├── routeflow/         # 分流脚本与默认 GWF 列表
│   │   ├── www/               # Web 页面与多语言字典
│   │   └── rc/                # 启动与事件处理
│   └── linux-3.4.x/           # 内核
├── toolchain-mipsel/          # 交叉工具链下载脚本
└── docs/                      # 开发笔记
```

---

## 致谢

- [hanwckf/rt-n56u](https://github.com/hanwckf/rt-n56u) — 本项目的基础
- [gorden5566/padavan](https://github.com/gorden5566/padavan) — 汉化字典
- [padavan/rt-n56u](https://bitbucket.org/padavan/rt-n56u) — 原始 Padavan 项目

## 许可

本项目遵循原项目 GPL-2.0 许可，详见 [License](trunk/License)。
