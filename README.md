# offline-html-app

**把"做个小应用"压缩成一个 `.html` 文件** —— 双击就开、断网能用、微信直接发给人。

这是一个给 AI 编程助手（Qoder / Claude Code 等支持 Skill 的 agent）用的技能包。装上之后你说"做个进货台账"或"做个能改的 A4 菜单"，agent 就照着**已经实测过的骨架**做出一个零依赖的单文件 HTML：CSS、JS、第三方库、中文字体、图片全部 data URI 内联，不发一个网络请求，iPhone Safari / 安卓自带浏览器 / Edge / Chrome / Windows / Mac 打开就能用。

适合"为一个定制化功能不值得去开发 App 或小程序"的场景：省掉开发、打包、上架、审核，当天拿到能用的文件；后续改文字换图，你自己打开文件就能做。

---

## 能做什么

| 形态 | 典型需求 | 能力 |
| --- | --- | --- |
| `artboard` 画布导出类 | 菜单、海报、名片、桌号标签、邀请函 | 页面内点选改字、图片位换图、竖版横版合一、导出 300dpi 图片、A4 正好一页打印、工程文件自包含 |
| `data` 数据应用类 | 进货台账、库存效期、名单签到、报价记录 | IndexedDB 本地库（实测配额约 128GB）、CSV/JSON 导入导出、分页列表、手机卡片视图、列表打印 |
| `tool` 本机批处理类 | 图片批量压缩加水印、格式互转 | 从数据骨架改，几十张图一次进、本机处理不上传、批量导出 |

**判据一句话**：关掉 WiFi 还能完整工作吗？不能就别用这套 —— 多人共享数据、账号登录、支付、推送、实时摄像头、蓝牙要走联网方案，技能里会明确说明为什么，并给出替代路线，不硬做。

## 快速开始

```bash
# 用户级安装（Windows 路径换成 C:\Users\<你>\.agents\skills\）
git clone https://github.com/Cer11/offline-html-app.git ~/.agents/skills/offline-html-app
```

Windows PowerShell 一条命令：

```powershell
git clone https://github.com/Cer11/offline-html-app.git "$env:USERPROFILE\.agents\skills\offline-html-app"
```

**不想碰 git 的**：去 [Latest Release](https://github.com/Cer11/offline-html-app/releases/latest) 下载 `offline-html-app-v1.2.zip`（50 KB），解压出来就是 `offline-html-app` 文件夹，整个放进上面的 skills 目录即可。

国内网络走 Gitee 镜像：克隆地址换成 `https://gitee.com/zhangzhihui1998/offline-html-app.git`，不想克隆就直接下仓库里的 [`dist/offline-html-app-技能包.zip`](https://gitee.com/zhangzhihui1998/offline-html-app/raw/main/dist/offline-html-app-%E6%8A%80%E8%83%BD%E5%8C%85.zip)（与 Release 里那份字节一致）；只想给单个项目用，就克隆到项目里的 `.qoder/skills/offline-html-app`。

重启会话（或 `/skills reload`）后直接说需求即可命中，例如：

> 用 offline-html-app 做一个进货台账，要能记品名数量单价、自动算金额、按月汇总、能导 CSV，手机上也要能用。

**不想用 agent 的**，`examples/` 里是三个做好的成品，下载下来双击就能用：

- [`examples/进货台账.html`](examples/进货台账.html) —— 记账，IndexedDB 本地库 + CSV 导入导出 + 手机卡片视图
- [`examples/桌号二维码标签.html`](examples/桌号二维码标签.html) —— 填桌数自动出 A4 标签页，二维码可扫
- [`examples/图片批量压缩.html`](examples/图片批量压缩.html) —— 批量压缩缩放加水印

（示例里的店名默认值是"示例餐厅"，打开就能改成你自己的。）

## 目录结构

```
offline-html-app/
├─ SKILL.md                        工作流 + 反复出现的坑
├─ assets/
│  ├─ starter.html                 画布导出类骨架（点选编辑、导出图片、A4 打印、工程文件自包含）
│  └─ starter-data.html            数据应用类骨架（IndexedDB+退路、CSV/JSON、分页、CSS 响应式卡片）
├─ scripts/
│  ├─ syntax.js                    内联脚本语法预检，直接报文件行号（需要 node，没有则降级提示）
│  ├─ audit.sh                     发布前体检，按 profile 分支检查，有 FAIL 退出码非 0
│  └─ a4.js                        纸张 mm ↔ 画布 px ↔ 导出像素 ↔ 打印 zoom ↔ 出血
├─ references/
│  ├─ capability-map.md            file:// 与 https 实测能力表、A/B/C 线、三档发布、体积边界
│  ├─ packaging.md                 源码布局、构建拼接、第三方库内联、中文字体子集化、图片压缩
│  ├─ export-print.md              html2canvas 兼容坑表、中和 + 四级重试、打印三件套与症状对照
│  ├─ portability.md               状态模型、存储兜底、工程文件自包含、各内核/设备坑对照
│  └─ verification.md              数值化验收探针、阈值、测试方法学教训
├─ examples/                       三个实测成品 + 一份 CSV 样例
└─ dist/offline-html-app-技能包.zip  同一份内容的 zip（50 KB）；对外分发优先用 Release 里的 offline-html-app-v1.2.zip
```

## 实测数字

技能不是照着文档写的，是拿它真做了三个应用、把撞出来的问题全部回修之后定稿的。

| 对象 | 关键实测 | 发布前体检 |
| --- | --- | --- |
| 进货台账 | 2000 条 CSV 导入落库 **1481ms**；分页后 DOM 101 行；含逗号/引号字段逐字段还原；刷新读回 2005 条 | 0 FAIL 0 WARN |
| 桌号二维码标签 | 导出 **2480×3508**；二维码深色像素占比 **38%**（真码区间）；24 桌→2 页、30 桌→3 页；打印模拟 **209.3×296.1mm** 正好一页 | 0 FAIL 1 WARN |
| 图片批量压缩加水印 | 4000×3000→1600×1200（1.32MB→257KB）；小图**不放大**；伪造 jpg 正确报错；WebP 自动探测 | 0 FAIL 0 WARN |
| starter-data 骨架 | 增删改、CSV 往返、分页、打印、手机卡片视图全通过 | 0 FAIL 0 WARN |

## 能力边界（桌面 Chromium，`file://` 实测）

**可用**：IndexedDB、localStorage、WASM、Web Worker、WebGL、文件下载、canvas 编解码。

**API 存在但被运行时拒绝**：剪贴板、定位、File System Access、Service Worker、屏幕常亮、通知。

**单文件方案做不到**：多人共享数据、账号登录、微信支付、消息推送、实时摄像头、蓝牙。

解锁前一类只要把同一个文件挂到任意静态 https 托管 —— 不需要后端、不需要审核，还能"添加到主屏幕"当 App 用。三档发布方式（本地文件 / 静态 https / 套壳）的取舍见 `references/capability-map.md`。

**存储被禁时**（无痕模式、部分手机浏览器）：页面不白屏，照常记录与导出，环境自检行会如实显示"本机存不住，记录只在这次打开里有效，务必用「导出备份」带走"。这条链路是用"把 indexedDB 和 localStorage 都定义成抛异常"模拟验出来的。

## 已知限制

1. **没有真机验证**。iPhone Safari 打开本地文件的存储行为、安卓各家内核（微信 / UC / 夸克 / 小米 / 华为）的多文件下载与相机调用，只做了 UA 识别和"存储被禁"的模拟。每个应用里都留了「环境」自检行，用户截图即可定位。
2. **打印只验到浏览器的打印媒体模拟**，实体打印机的边距与缩放精度未测。主交付路径建议始终是先导出图片。
3. **HEIC 解不了**：iOS 相册直出格式在多数浏览器里读不了，工具类应用只能提示先转 JPG。
4. **体积天花板**：单文件目标 300KB–1.5MB、8MB 硬上限；OCR、语音这类几十 MB 的 wasm 模型不适合走单文件。
5. `syntax.js` / `a4.js` 需要本机有 node，`audit.sh` 需要 bash。缺哪个，脚本会明确提示改用哪条人工路径，不会静默跳过。

## 许可

MIT —— 见 [LICENSE](LICENSE)。
