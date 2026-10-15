---
name: offline-html-app
description: 做「单个 .html 文件、双击就能用、断网也能用」的离线网页小应用与可编辑模板。三种 profile：画布导出类（菜单、海报、名片、标签、邀请函——页面内改文字换图、导出 300dpi 图片、A4 一页打印）、数据应用类（进货台账、库存、名单、签到、报价——IndexedDB 本地库、CSV/JSON 导入导出、分页列表、手机卡片视图）、本机批处理工具类（图片批量压缩加水印、格式互转，从数据骨架改）。通过微信或文件分发，在 iPhone Safari、安卓自带浏览器、Edge/Chrome、Windows/Mac 上打开即用。用户说"做个能用浏览器打开的网页/HTML 小工具/模板/封装成网页""发给客户手机上要能改""不要依赖服务器""能不能不开发 App 就实现"时使用。需要账号、多人共享、支付、推送、实时摄像头时改用联网方案。
---

# 单文件离线 HTML 小应用

## 概述

交付物是**一个 .html**：CSS、JS、第三方库、字体、图片全部 data URI 内联，零网络请求。用户双击或手机浏览器打开即可用，改完导出图片或打印，跨设备靠「保存工程 / 导出备份」。

价值全在细节：老内核语法兼容、中文字体子集、html2canvas 兼容、A4 尺寸换算、存储兜底、手机触控预算。**从骨架改，不要从零写**——骨架里躺着的全是踩过的坑。

判据一句话：**关掉 WiFi 还能完整工作吗？** 不能就别用这套（走联网技能）。

## 第 0 步：判形态，选骨架

先读 `references/capability-map.md`，把需求落到 A/B/C 线和一种 profile：

| profile | 长什么样 | 用哪个骨架 | 典型需求 |
| --- | --- | --- | --- |
| `artboard` | 固定尺寸画布 + 导出图片/打印一页 | `assets/starter.html` | 菜单、海报、名片、桌号标签、邀请函 |
| `data` | 列表/记录 + 本地数据库 + 导入导出 | `assets/starter-data.html` | 进货台账、库存效期、名单签到、报价记录 |
| `tool` | 输入文件 → 本机处理 → 输出文件 | 从 `starter-data.html` 改（去掉表格，换文件队列） | 图片批量压缩加水印、CSV 互转 |

在文件 `<head>` 里写 `<!-- profile: artboard|data|tool -->`，`scripts/audit.sh` 按它决定查哪些项（不写就自动猜，猜错会误报）。

需求落在 capability-map 的 **C 线**（多人共享、账号、支付、推送、实时摄像头、蓝牙）时，直接说明为什么单文件不行、给 ②静态 https 或 ③套壳/小程序的替代，不要硬做。

## 工作流

1. **定尺寸/形态**。打印类先跑 `node scripts/a4.js 210 297`（或 `297 210`、大16开 `210 285 150 300 3`），把画布 px、导出 px、打印 zoom 抄进代码。模型固定：**画布按 150dpi CSS px 写死，导出 `scale:2` 即 300dpi**。
2. **复制骨架**，改内容与样式。骨架已带：无 JS 兜底条、二级确认弹窗、存储 try/catch、撤销、环境自检行、手机适配、打印规则。
3. **语法先过一遍**：`node scripts/syntax.js 文件.html`（给出行号）。**没有 node 就先加载一次页面读控制台**——语法错误是整页白屏，靠交互测试根本问不出为什么。
4. **内联资源**：见 `references/packaging.md`。中文字体必须子集化（iOS/安卓没有楷体行楷会静默换字体）；第三方库下载一份存着，永远内联。
5. **按 `references/export-print.md` 做导出/打印**：artboard 用 `@page size` + `zoom` + `print-color-adjust` 三件套；data 列表用自然分页，**不要套画布那套 zoom**。
6. **验收**：`bash scripts/audit.sh 文件.html` 必须 0 FAIL，再按 `references/verification.md` 跑数值探针。没有 bash/Windows 只有 CMD 时，把 `audit.sh` 当人工清单照着核（它就是把 verification 的检查项自动化了），别跳过。

## 反复出现的坑（都是实测撞过的）

- **辅助函数的空 class 参数**：`E('button','',…)` 会让按钮**没有基类**，于是 CSS 选择器和测试断言一起失效。骨架里的 `mkbtn` 已强制补 `btn`；自写 helper 时要同样处理，并且**断言 computed style，而不是只断言 DOM 存在**。
- **提示文案里的 `<b>`**：用 `textContent` 赋值会把标签当字面量显示给用户（这个错在两个不同项目里各复发一次）。要么统一走 `innerHTML` 辅助函数，要么文案里不写标签。
- **路径寻址混入 UI 标签**：`[['brand','name','店名'],…]` 直接传给 `gp(k)` 会多走一层，返回 `undefined` → 输入框永远空白、改动静默丢失。路径要 `k.slice(0,2)`。
- **写回目标必须是"持有该字段的对象"**：图片写 `v.img=d`，路径就得指向对象（`['mast']`），写成 `['mast','img']` 拿到字符串，`'use strict'` 下抛错、非严格下静默无效。
- **文件选择器要同时记写回位置**：只设 `cur` 不设 `imgTarget`，change 回调第一行就 return，表现为"点了没反应"。统一走一个 `pickAt(path)`。
- **一次渲染几千行**：手机上会卡死或被系统杀掉。列表默认分页（每页 100），打印前再临时展开全部。
- **别用 JS 判断视口渲染两套结构**：resize 事件在自动化和部分手机上不可靠，会出现"手机上还是桌面表格"。用**同一份 DOM + CSS 变形**（`@media` 里 `table,tr,td{display:block}` + `td::before{content:attr(data-l)}`）。
- **验证半透明叠加内容**：用"同区域开/关差值"，并且要选对统计量——均值会被大面积背景稀释；位置正确性用"文字应在的区域 vs 不应在的区域"对比最可靠。
- **手机屏幕预算**：设置面板 + 工具条超过 400px 就会把内容挤没（实测 634/844）。窄屏要把设置折叠成抽屉。
- **破坏性操作三层保险**：独立按钮 → 页面内二级确认（写清丢什么、能不能撤）→ 执行前 `snap()`。**不要用原生 `confirm()`**，微信内核经常吞掉。
- **存储 key 带版本号**：结构一改就 +1，否则老用户读到旧数据，会来报"改动没生效"。

## 交付话术

用户通常不知道这些，主动讲清：**微信里直接点开只能看不能改**（要点「···」→用其他应用打开→浏览器）；**改动只存在当前这台设备**（跨设备用「保存工程 / 导出备份」）；**导出图片是打印最省事的路**（发打印店，A4 300dpi）；**想装到手机首屏/要相机定位**就把同一个文件挂到任意静态 https 托管（不需要后端、不需要审核），见 capability-map 的三档发布。

报告结果时把"实测到的"和"没条件验的"分开说（真机 Safari、真打印机通常验不了）。

## Resources

- `assets/starter.html` — artboard 骨架：点选编辑、图片位、导出图片、A4 打印、工程文件自包含
- `assets/starter-data.html` — data 骨架：IndexedDB+退路、CSV(BOM)/JSON 备份、分页列表、CSS 响应式卡片、列表打印
- `scripts/syntax.js` — 内联脚本语法预检，报文件行号（浏览器之前先跑）
- `scripts/audit.sh` — 按 profile 体检，输出 PASS/WARN/FAIL，有 FAIL 退出码非 0
- `scripts/a4.js` — 纸张 mm ↔ 画布 px ↔ 导出像素 ↔ 打印 zoom ↔ 出血
- `references/capability-map.md` — file:// 与 https 实测能力表、A/B/C 线、三档发布、体积与性能边界
- `references/packaging.md` — 源码布局、构建拼接、内联第三方库、中文字体子集化、图片压缩
- `references/export-print.md` — html2canvas 兼容坑、中和+四级重试、打印三件套与症状对照
- `references/portability.md` — 状态模型、存储兜底、工程文件自包含、各内核/设备坑对照
- `references/verification.md` — 数值化验收探针、阈值、测试方法学教训
