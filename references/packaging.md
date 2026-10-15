# 装配成单文件（内联一切）

目标：**一个 .html，断网可用，双击/手机浏览器直接打开**。任何 `http(s)://` 引用都算缺陷，用 `scripts/audit.sh` 卡住。

## 源码布局（别直接改成品）

成品是构建产物，改一次要重跑构建，所以源文件分开存放：

```
项目根/
├─ 应用名.html              ← 构建产物，交付物
├─ _源文件/
│  ├─ _m1.html              ← head + CSS + 骨架，中间放 /*__FONTS__*/ 标记
│  ├─ _m2.html              ← 引擎 JS（ES5）
│  ├─ _data.js              ← 内容数据（文案/条目），改内容只动这里
│  ├─ html2canvas.min.js    ← 第三方，下载一次存着
│  ├─ Ma-Shan-Zheng.woff2   ← 子集化后的字体
│  ├─ NSS.woff2
│  ├─ chars.txt             ← 需要哪些汉字，一行或连续字符串
│  └─ _build.sh
└─ imgs/                    ← 原始图片（会被压成 data URI 再内联）
```

`_build.sh` 的骨架（`sed` 按标记切分，再 `cat` 拼起来）：

```bash
set -e; cd "$(dirname "$0")"; OUT="../"
{ printf '@font-face{font-family:"X";src:url(data:font/woff2;base64,'; base64 -w0 X.woff2; printf ')format("woff2");}\n'; } > _font.css
{ printf 'var HERO_URI="data:image/jpeg;base64,'; base64 -w0 ../imgs/banner.jpg; printf '";\n'; } > _assets.js
N=$(grep -n '__FONTS__' _m1.html | cut -d: -f1)
sed -n "1,$((N-1))p" _m1.html > _m1a.html; sed -n "$((N+1)),\$p" _m1.html > _m1b.html
printf '</script>\n<script>\n' > _mid.txt
cat _m1a.html _font.css _m1b.html html2canvas.min.js _mid.txt _assets.js _data.js _m2.html > "${OUT}应用名.html"
grep -Eo 'src="https?://[^"]*"|@import' "${OUT}应用名.html" | wc -l   # 必须是 0
```

拼接顺序里 `</script><script>` 是必须的：html2canvas 自己带 `</script>` 之前，前面的 `<script>` 还没闭合，直接 `cat` 会把引擎吞进它的脚本块里（表现为"引擎根本没跑"）。

## 第三方库

`html2canvas.min.js`（198 KB，1.4.1）下载一次存进 `_源文件/`，永远内联，不要留 CDN 引用：

```bash
curl -sL -o html2canvas.min.js https://cdn.jsdelivr.net/npm/html2canvas@1.4.1/dist/html2canvas.min.js
head -c 60 html2canvas.min.js    # 应看到 "html2canvas 1.4.1" 注释头，audit.sh 靠它判断已内联
```

只用到截图这一个能力时，别再引入框架。整个应用用 ES5 + 原生 DOM 就够，且老内核兼容性最好。

其它常用库同样"下载一次、存进 `_源文件/`、构建时内联"（实测体积，都值得）：

| 库 | 用途 | 内联后体积 |
| --- | --- | --- |
| `qrcode-generator@1.4.4`（MIT） | 二维码（桌号标签、核销码、名片链接） | 20.8 KB |
| `SheetJS`（社区版） | 读写 xlsx | 400 KB+，能不用就不用（CSV 够用） |
| `jsPDF` | 前端出 PDF | 300 KB+，能用「打印→另存为 PDF」就别内联 |

用法固定三步：`curl -sL -o 库.js https://cdn.jsdelivr.net/npm/<包>@<版本>/<文件>` → 在骨架里留 `/*__库__*/` 标记 → 构建时替换。**替换时注意**：库和引擎之间仍要靠 `</script><script>` 分隔；用 `String.replace(marker, ()=>库内容)` 而不是普通字符串替换，否则库里的 `$&`、`$1` 会被当成替换模式吃掉（实测踩过，表现为库莫名其妙少了字符）。

二维码这类"由代码画出来的图"要先 `canvas.toDataURL()` 再塞进 `<img>`，html2canvas 对 `<img>` 的支持远好于对多个小 `<div>` 拼的模块矩阵。

## 声明应用形态

`<head>` 里写一行，让 `audit.sh` 按形态检查（否则它会拿画布类的规则去要求数据类应用，误报一堆 FAIL）：

```html
<!-- profile: artboard -->   或  data  或  tool
```

## 中文字体子集化（关键：iOS/安卓没有楷体行楷，会静默回退）

系统字体列表里的 `"KaiTi","楷体","STXingkai"` 在 iPhone / 安卓上**根本不存在**，浏览器会悄悄换成黑体，设计就废了。要保字体就必须把字体本身装进文件——但完整中文字体 5–10 MB，所以只取用到的字：

```bash
# 1) 收集要用的字符（标题、正文、按钮、数字、标点都要，宁多勿漏）
tr -d '\n' < chars.txt > _one.txt
# 2) 问 Google Fonts 要这个字符集的 woff2 地址（必须带现代 UA，否则回吐 ttf）
CHARS=$(python -c "import urllib.parse,io;print(urllib.parse.quote(io.open('_one.txt',encoding='utf-8').read()))" 2>/dev/null \
     || perl -MURI::Escape -ne 'print uri_escape($_)' _one.txt)
curl -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120 Safari/537.36" \
  "https://fonts.googleapis.com/css2?family=Ma+Shan+Zheng&text=${CHARS}" | grep -o 'https://[^)]*\.woff2'
# 3) 下载 → base64 → 内联（654 字 ≈ 12 KB，完全可接受）
curl -sL -o Ma-Shan-Zheng.woff2 "<上一步的 URL>"
```

- 字体授权要挑清楚的：`Ma Shan Zheng`、`Noto Serif SC`、`ZCOOL` 系都是 OFL/SIL，可商用。
- 数字单独注意：Georgia/Times 是**旧式数字**（高低不齐、带下伸），价格/编号看着很乱；数字用正文字体并加 `font-variant-numeric:lining-nums tabular-nums`。
- 漏字的表现是"个别字变成黑体"，验收时要专门扫一遍所有文案。

## 图片：先压再内联

内联前必须压，否则文件轻松上 5 MB，微信传不动、手机打不开：

- 单张 data URI 控制在 **300 KB 以内**；`shrink()` 里已经按最长边 900px + JPEG q0.86 处理用户上传的图，内置素材也要照这个标准预处理。
- 没有 ImageMagick 时用 PowerShell + System.Drawing（裁剪、缩放、转 JPEG）：

```powershell
Add-Type -AssemblyName System.Drawing
$b=[System.Drawing.Bitmap]::FromFile('C:\in.png')
$c=$b.Clone([System.Drawing.Rectangle]::new(0,0,$b.Width,$b.Height-52),$b.PixelFormat)  # 裁掉底部水印
$o=[System.Drawing.Bitmap]::new(900,[int]($c.Height*(900/$c.Width)))
$g=[System.Drawing.Graphics]::FromImage($o); $g.InterpolationMode='HighQualityBicubic'
$g.DrawImage($c,0,0,$o.Width,$o.Height)
$ep=[System.Drawing.Imaging.EncoderParameters]::new(1)
$ep.Param[0]=[System.Drawing.Imaging.EncoderParameter]::new([System.Drawing.Imaging.Encoder]::Quality,[long]82)
$codec=[System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders()|?{$_.MimeType -eq 'image/jpeg'}
$o.Save('C:\out.jpg',$codec,$ep)
```

- 矩形定位要**先量再裁**：用像素亮度扫出目标区域（比如水印 bbox），别凭眼看。
- AI 生成图当素材时，务必在提示词里排除 `text, calligraphy, seal, watermark, border`，生成后仍要检查角落有没有水印，有就裁掉。

## 体积预算

| 部分 | 合理区间 |
| --- | --- |
| html2canvas | 198 KB |
| 中文字体子集（1–2 个） | 10–40 KB |
| 内置图片（1–3 张） | 30–300 KB |
| 引擎 + 内容 | 30–80 KB |
| **成品** | **300 KB – 1.5 MB** |

超过 8 MB 就要拆图或降分辨率；微信文件上限虽宽，但手机端浏览器解 base64 会吃内存。
