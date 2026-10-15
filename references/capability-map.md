# 能力边界：单文件能做到哪、什么时候必须换方案

下面这张表是**实测**出来的，不是文档转抄。测试环境：桌面 Chromium（`isSecureContext=true` 的 `file://`）。iPhone Safari / 安卓自带浏览器没有真机可测，差异见最后一节。

**核心结论：`file://` 下 API "存在" 不等于 "能用"。** 权限类 API 全部在运行时被拒（弹不出授权框），存储与计算类全部可用。

## 实测结果

| 能力 | `file://` 实测 | 说明 |
| --- | --- | --- |
| IndexedDB | ✅ 可用，配额约 **128 GB** | 本地数据库类应用的底气 |
| localStorage | ✅（iOS 可能抛异常） | 只放配置；必须 try 包住 |
| WebAssembly / Worker / OffscreenCanvas / WebGL | ✅ | 能跑 SQLite(wasm)、图表、图像算法 |
| `<input type=file>` 多选、`capture` | ✅ | 拍照走系统相机，不要走 getUserMedia |
| 下载 `a[download]`、`URL.createObjectURL` | ✅ | 导出 CSV/JSON/图片的主路径 |
| `canvas.toDataURL/toBlob` | ✅（toBlob 老内核缺失，需兜底） | 单画布约 **16.7M px** 上限 |
| `navigator.getBattery` | ✅ | |
| `navigator.clipboard.writeText` | ❌ NotAllowedError | 退回 `document.execCommand('copy')` |
| 定位 geolocation | ❌ code1 权限被拒 | |
| 实时摄像头 getUserMedia | ⏸ 本机无摄像头未测出；需 https | 用相册/系统相机替代 |
| File System Access（showOpenFilePicker） | ❌ SecurityError | 用普通 `<input type=file>` |
| Service Worker / PWA 安装 | ❌ 注册失败 | 必须 https |
| wakeLock 屏幕常亮 | ❌ NotAllowedError | |
| Notification 通知 | ❌ denied | |
| `navigator.share` | 桌面 Chrome **本来就没有**（与 file:// 无关） | 手机才有；永远保留"长按保存"兜底 |

## 三条线：怎么判断该不该用单文件

**A 线 · 单文件完全够（优先选它，比做 App 快一个数量级）**
一切"数据在用户自己手里、输入 → 本机处理 → 输出文件"的功能：
记账/进销存、库存与效期提醒、排班表、名单与签到、报价单、可编辑模板（菜单/海报/名片/标签）、二维码与标签打印、图片批量压缩加水印、CSV↔Excel 互转、图表看板、Markdown/笔记、离线 SQLite 数据库应用、计算器、表单收集后导出。

**B 线 · 能做但要绕，绕法要提前告诉用户**
拍照（系统相机而非实时取景）、扫码（相册选图+解码，而非摄像头流）、复制（execCommand）、分享（下载+长按）、提醒（只在页面开着时算）、地图瓦片（离线不行）。

**C 线 · 别硬上，换方案**
多人共享同一份数据、账号登录、微信支付/订阅消息、后台常驻、推送、读写通讯录日历、蓝牙/NFC/USB 硬件、上架应用商店。→ 要后端用 sites 那套联网技能；要微信身份/支付就只能做小程序。

## 三档发布（同一份代码，成本递增）

| 档 | 怎么给 | 解锁什么 | 代价 |
| --- | --- | --- | --- |
| ① 单文件 | 微信传、U 盘、内网共享 | 无（权限最受限） | 零成本，改一次发一次 |
| ② **静态 https 托管** | GitHub Pages / 对象存储 / 内网 nginx，**不需要后端程序、不需要审核** | 相机、定位、剪贴板、wakeLock、Service Worker、PWA「添加到主屏幕」、自动更新 | 要一个域名/空间；断网不可用 |
| ③ 套壳 | Electron/Tauri（桌面）、Capacitor（APK） | 系统集成、开机自启、离线安装包 | 签名、打包、分发全要自己做 |

**②是"像 App 但不必开发 App"的甜点区**：代码一行不用改，把上面这张表里 ❌ 的项目几乎全部转成 ✅，还能装到手机首屏。用户说"想要 App 的感觉"时先问一句能不能挂 https。

## 体积与性能边界

| 项 | 经验值 |
| --- | --- |
| 单文件体积 | 目标 300KB–1.5MB；>8MB 微信传输和手机解码都吃力 |
| 中文字体子集 | 650 字约 12KB（整字体 5–10MB，绝不能整包内联） |
| 一张内联照片 | 最长边 900px + JPEG q0.85 ≈ 40–120KB |
| 一次进 DOM 的行数 | ≤200；更多要分页 |
| 画布总像素 | ≤16M（iOS 上限），450dpi A4 手机上必炸 |
| 连续下载 | 手机浏览器会拦；>5 个文件要提示或逐张 |
| 大模型（OCR/语音/翻译） | 几十 MB，不适合单文件；放 ② 档按需加载 |

## 存储被禁时的实测行为（模拟 iOS/无痕）

用初始化脚本把 `indexedDB` / `localStorage` 定义成抛异常的 getter，再加载 `starter-data.html`：

| 场景 | 实测 |
| --- | --- |
| 只有 IndexedDB 被禁 | 自动退回 localStorage，环境行如实写"已退回"，增删改可用，刷新后读回 ✓ |
| IndexedDB 打开时既不 success 也不 error | 3 秒超时兜底转退路（**必须有这个超时**，否则会永远卡在"加载中"） |
| 两个都被禁 | 页面照常启动、照常记录、照常导出 CSV/BOM；环境行明确写"本机存不住（无痕模式或浏览器禁用存储）　记录只在这次打开里有效，务必用「导出备份」带走" |

**踩出来的教训**：退路分支不要重复写数据（调用方已经把记录放进内存数组，落盘函数再 push 一次就变成每条存两遍，实测 `共 2 笔` 而不是 1 笔）；保存成功的提示必须区分"真落盘"和"只在内存里"，**报"已保存"其实没保存是最坏的一种 bug**。

## 没测到的、要在真机确认的

1. **iPhone Safari 打开本地 html**：`localStorage`/IndexedDB 是否可用、QuickLook 是否跑 JS（不跑就是 `#nojs` 那段兜底在替你说话）。
2. **安卓各家内核**（微信 X5、UC、夸克、小米/华为浏览器）：下载多文件、`capture` 调相机、WebP 编码支持度。
3. **真打印机**：`@page` 与 `zoom` 的落纸精度（自动化里只能验到打印媒体模拟）。
4. 因此界面里要留一行**环境自检**（UA 判定 + 存储是否可用 + 依赖是否就绪），用户截图即可定位。
