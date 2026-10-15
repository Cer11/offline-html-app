# 导出图片与打印（html2canvas 实战）

## 尺寸模型：先定画布，再谈导出

**画布用「150dpi 的 CSS px」写死，导出时 `scale:2` 就是 300dpi。** 这样屏幕上看的是 1 倍尺寸，出图是 2 倍，两者比例恒定，验证时只要测一种。

```bash
node scripts/a4.js 210 297            # A4 竖版
node scripts/a4.js 297 210            # A4 横版
node scripts/a4.js 210 285 150 300 3  # 大16开 + 3mm 出血
```

输出（A4 竖版）：画布 `1240×1754` CSS px，导出 `scale 2 → 2480×3508 px`，打印 `zoom 0.64`（写 **0.638**，略小以免四舍五入溢出到第 2 页）。换算记一句话：**1 CSS px ≈ 0.169 mm，画布上任意 N px 的元素，素材按 N×2 的像素出**。

打印店常用的是大16开 210×285mm（比 A4 便宜），客户没指定时提一句。

## html2canvas 实测过的坑

| 症状 | 原因 | 修法 |
| --- | --- | --- |
| 渐变文字整块变成纯色矩形，字没了 | 不支持 `-webkit-background-clip:text` | 改实色 + `opacity`，别用渐变裁字 |
| `createPattern ... width or height of 0` 抛错 | 高度 1px 的**渐变**细线，在非 100% 显示缩放下被取整成 0 | 细线一律用 `solid` 颜色；导出前再跑 `neutralize()` |
| 导出的图没有背景图/背景色 | 只影响打印，不影响 canvas | 打印见下一节；canvas 侧检查元素是否 `display:none` |
| 老 Safari 点导出没反应 | `canvas.toBlob` 不存在 | `cvBlob()` 兜底到 `toDataURL` + `atob` 拼 Blob |
| 手机上导出失败/页面被杀 | 画布面积超 iOS 上限（约 16.7M px） | 450dpi 在手机上必然超限；失败时自动按 1 倍重试 |
| 截图模糊或只截到一部分 | 画布被 `transform:scale()` 缩放过 | 导出前 `wrap.style.transform='none'`，结束再恢复 |

**实测可用**（不用绕）：`object-fit:cover`、`writing-mode:vertical-rl`、dashed 边框、`grid-auto-flow:column`、CSS 变量、`box-shadow`（会被忽略）。

## 导出：中和 + 四级重试

```js
function neutralize(){                     // 把"高度为 0 但有背景图"的元素临时清掉
  var hit=[];
  board.querySelectorAll('*').forEach(function(e){
    if(e.getBoundingClientRect().height>=1)return;
    var cs=getComputedStyle(e);
    if(cs.backgroundImage&&cs.backgroundImage!=='none'){hit.push([e,e.style.backgroundImage]);e.style.backgroundImage='none';}
  });
  return hit;
}
function shoot(scale){                     // 依次尝试：2倍 → 2倍+foreignObject → 1倍 → 1倍+foreignObject
  var base={backgroundColor:'#fff',width:W,height:H,x:0,y:0,scrollX:0,scrollY:0,
            windowWidth:W,windowHeight:H,logging:false,useCORS:true,imageTimeout:25000};
  var tries=[Object.assign({scale:scale},base),Object.assign({scale:scale},base,{foreignObjectRendering:true}),
             Object.assign({scale:1},base),Object.assign({scale:1},base,{foreignObjectRendering:true})];
  var p=Promise.reject(new Error('begin'));
  tries.forEach(function(o,n){p=p.catch(function(){return window.html2canvas(board,o);});});
  return p;
}
function cvBlob(cv,cb){                    // toBlob 缺失/返回 null 时退回 dataURL
  if(cv.toBlob){try{cv.toBlob(function(bl){cb(bl||null);},'image/png');return;}catch(e){}}
  try{var u=cv.toDataURL('image/png'),s=atob(u.split(',')[1]),a=new Uint8Array(s.length);
    for(var i=0;i<s.length;i++)a[i]=s.charCodeAt(i);cb(new Blob([a],{type:'image/png'}));}catch(e){cb(null);}
}
```

拿到 `bl===null` 且 `scale>1` 时，**自动按 1 倍再来一次**并提示用户，比报"导出失败"有用得多。

导出后把图放进一个浮层预览（`naturalWidth` 就是真实像素），手机长按可存、桌面右键可另存，再给一个 `navigator.share({files})`（要先 `navigator.canShare({files:[f]})` 判断，且整体包 try/catch）。

## 打印：三条缺一不可

```css
@media print{
  #bar,#mask,#sheet,#toast,#busy,#ask,#nojs{display:none!important}
  html,body{background:#fff;margin:0;padding:0;overflow:visible}
  #stage{padding:0;margin:0;overflow:visible}
  #wrap{transform:none!important;width:auto!important;height:auto!important}
  #board{box-shadow:none;margin:0;zoom:.638}                 /* ② 缩到纸张 */
  #board,#board *{-webkit-print-color-adjust:exact;print-color-adjust:exact}  /* ③ 保背景 */
}
```

```html
<style id="pagecss">@page{size:210mm 297mm;margin:0}</style>   <!-- ① 定纸张 -->
```

```js
$('pagecss').textContent='@page{size:'+(横版?'297mm 210mm':'210mm 297mm')+';margin:0}';  // 跟版式切换
```

症状对照：

| 症状 | 缺了哪条 |
| --- | --- |
| 多出第 2 页、角落孤零零几行字 | ② 没缩放（画布 CSS px 比 A4 物理尺寸大） |
| 背景图、色块、渐变全没了 | ③ `print-color-adjust` |
| 横版内容打在竖纸上、右边被切 | ① `@page size` 没跟版式切换 |
| 预览正常、真机整体偏小 | 打印机自己的安全边距，选「无边距」或接受 96% |

**验收方式**：Playwright `page.emulateMedia({media:'print'})` 后量 `board.getBoundingClientRect()`，A4 竖版应得 `791×1119 px ≈ 209.3×296.1 mm`，正好一页；再截一张图确认背景在。这比"看起来对"可靠。真打印机仍要用户自己试一次。

## 交付取向

主路径永远是**导出图片**（像素确定、可自动验证、发打印店最省事），打印只作为补充。给用户的提示词就写清：手机长按图片发微信，电脑右键另存。
