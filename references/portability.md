# 状态、跨设备带走、以及各内核的坑

## 状态模型：DOM 不是真相

单一 `state` 对象 + **路径寻址**：可编辑元素上挂 `data-e='{"p":["rows",0,"t"],"k":"text"}'`，点击时 `gp(o.p)` 取值、`sp(o.p,v)` 写值，`render()` 从 state 重建 DOM。好处是"导出/保存/撤销/跨设备"全都只是序列化一个对象。

```js
function gp(p){var c=state;for(var i=0;i<p.length;i++){if(c==null)return undefined;c=c[p[i]];}return c;}
function sp(p,v){var c=state;for(var i=0;i<p.length-1;i++)c=c[p[i]];c[p[p.length-1]]=v;}
```

三个真实踩过的坑（都会表现为"改了没反应"，且不报错）：

1. **把带标签的数组当路径传进去**。`[['brand','name','店名'],…]` 里第 3 个元素是界面文案，`gp(['brand','name','店名'])` 返回 `undefined` → 输入框永远空白、输入静默丢失。写 `var kp=k.slice(0,2)` 再传给 gp/sp。
2. **写回目标必须是"持有该字段的对象"**。图片槽要写 `v.img=d`，路径就得指向对象本身（`['mast']`），写成 `['mast','img']` 会拿到字符串，`'use strict'` 下给字符串加属性直接抛 `TypeError`，表现就是"点图换图没反应"。
3. **文件选择器要同时记住写回位置**。`$('fImg').click()` 之前必须设 `imgTarget`，否则 change 回调第一行 `if(!imgTarget)return;` 直接吞掉。凡是"换图"按钮统一走一个 `pickAt(path){cur={p:path,k:'img'};pickImage();}`，别在每个按钮里各写一遍。

## localStorage：三件事

```js
function lsGet(k){try{return localStorage.getItem(k);}catch(e){return null;}}
function lsSet(k,v){try{localStorage.setItem(k,v);return true;}catch(e){return false;}}
function storageOK(){try{localStorage.setItem(K+'_p','1');localStorage.removeItem(K+'_p');return true;}catch(e){return false;}}
```

- **必须包 try/catch**：iOS Safari 打开本地文件、各种无痕模式，直接访问 `localStorage` 会抛异常，写在启动路径上就是整页白屏。
- **key 要带版本号**（`app_v6`）。数据结构一改就 +1，否则老用户读到的还是旧结构，你会被判定"改动没生效"。
- **写失败要提示**（配额满，通常是图片太多），并引导用「保存工程」。

自动保存做防抖（700ms），别每次 `oninput` 都写。

## 工程文件：把状态嵌回自己

用户换设备/换浏览器的唯一可靠通道，是让他下载一个**包含全部内容和图片的同一个 html**。做法是克隆当前文档再注入一段 JSON：

```js
function projectHTML(){
  var c=document.documentElement.cloneNode(true);
  var bd=c.querySelector('#board'); if(bd) bd.innerHTML='';              // 清掉渲染产物
  ['#sheet','#askb','#toast'].forEach(function(s){var n=c.querySelector(s);if(n)n.innerHTML='';});
  ['#mask','#busy','#toast','#ask','#nojs'].forEach(function(s){var n=c.querySelector(s);if(n)n.removeAttribute('style');});
  var wp=c.querySelector('#wrap'); if(wp) wp.removeAttribute('style');   // 清掉缩放
  var old=c.querySelector('#app-state'); if(old) old.remove();
  var t=document.createElement('script'); t.type='application/json'; t.id='app-state';
  t.textContent=JSON.stringify(state).replace(/<\//gi,'<\\/');           // 防 </script> 提前闭合
  c.querySelector('head').appendChild(t);
  return '<!DOCTYPE html>\n'+c.outerHTML;
}
function extractState(txt){
  var m=txt.match(/<script[^>]*id="app-state"[^>]*>([\s\S]*?)<\/script>/i);
  if(m) return JSON.parse(m[1].replace(/<\\\//gi,'</'));
  var t=txt.replace(/^\s+/,''); if(t.charAt(0)==='{') return JSON.parse(t);
  throw new Error('文件里找不到应用数据');
}
```

启动顺序：内嵌 JSON > localStorage > 默认值，并在提示里告诉用户载入的是哪一种（"已载入本机自动保存的内容"），否则他会以为改动丢了。

**大资源要去重**：内联在文件里的默认图（`HERO_URI`）同时也被 `state` 引用，直接序列化会在一个文件里存两遍 base64。序列化时换成占位符，读回时还原：

```js
if(s.mast&&s.mast.img===HERO) s.mast.img='@HERO';     // pack
if(o.mast&&o.mast.img==='@HERO') o.mast.img=HERO;     // 载入后 sync() 里还原
```

实测一个 250KB 头图的项目：工程文件从 808K 字符降到 558K。撤销快照也要用同一个 pack()，否则 12 份快照就是 3MB 字符串。

**结构变更要能读旧文件**：写一个 `migrate(old)`，用特征字段判断版本（比如旧结构有 `top/cols` 而没有 `secs`），迁移不了就报错提示，不要静默生成空内容。

## 各内核 / 各设备的坑

| 环境 | 现象 | 处理 |
| --- | --- | --- |
| 微信直接点开 | 只预览，不跑 JS（iOS 的 QuickLook 也不跑） | `<body>` 顶部放一段**不依赖 CSS/JS** 的说明块，JS 一执行就 `display:none`；工程文件里也要保留 |
| 微信内置浏览器（安卓 X5） | JS 能跑，但下载和 localStorage 常受限 | UA 命中 `MicroMessenger` 就弹引导：右上角···→ 用其他应用打开 → 浏览器 |
| iOS Safari 本地文件 | `localStorage` 可能抛异常 | `storageOK()` 探测，不可用就把「保存工程」按钮高亮并弹提示 |
| 任何内置内核 | `confirm()` / `alert()` 经常不弹，等于没有确认 | 一律用页面内弹窗做二级确认（点背景/取消/Esc 都能退出） |
| 触屏 | 小按钮按不准 | 可点目标 ≥44px |
| iOS | 字号 <16px 的输入框聚焦时整页被放大 | 输入框 `font-size:19px` |
| 手机 | 画布比屏幕宽，禁缩放就没法看清 | viewport **不要** `user-scalable=no` / `maximum-scale` |
| 老安卓内核 | 用了 `?.` `??` → 语法错误，整页白屏 | 全 ES5；`audit.sh` 会扫 |
| 窄屏 | 工具条挤爆 | `@media(max-width:760px)` 收起次要按钮组，但那些功能必须在"设置/批量编辑"面板里都能找到 |

## 界面里留一行"环境自检"

把 UA 判定、`storageOK()`、依赖是否就绪直接显示在界面上：

```
环境：Safari/苹果　自动保存：不可用，请用保存工程　导出：已就绪
```

用户手机出问题时无需描述，截图这一行就能定位。这是这轮排查里性价比最高的一处。

## 破坏性操作：三层保险

`恢复默认` / `删除条目` 这类操作：**① 独立按钮（别和主操作同色）→ ② 页面内二级确认（写清丢什么、影响哪些版式、建议先保存工程）→ ③ 执行前 `snap()`，确认框里就告诉用户"按错了点撤销"**。实测三层都能独立生效，任何一层失守都不会真的丢数据。

## 数据类应用的存储层（实测）

`assets/starter-data.html` 里已实现，要点：

```js
function idbOpen(cb){
  try{
    var q=indexedDB.open(KEY,1);
    q.onupgradeneeded=function(){try{q.result.createObjectStore('rows',{keyPath:'id'});}catch(e){}};
    q.onsuccess=function(){S.db=q.result;S.idb=true;cb(true);};
    q.onerror=function(){cb(false);};                 // iOS 本地文件里会被禁
    setTimeout(function(){if(!S.idb)cb(false);},3000); // 有的内核既不 success 也不 error，会一直挂着
  }catch(e){cb(false);}
}
```

- **IndexedDB 为主，localStorage 为退路**：IDB 配额实测约 128 GB，localStorage 只有 5–10 MB，几百张图必爆。两条路都要有，并在界面「环境」行里写明当前用的是哪条。
- **一定要加超时兜底**：`open` 在某些安卓内核里既不触发 `onerror` 也不触发 `onsuccess`，没有超时就会永远停在"加载中"。
- **列表必须分页**（实测每页 100 行）：2005 条一次进 DOM，桌面重渲染 63ms 看着没事，手机上就是卡死点。打印前再临时展开全部行。
- **CSV 三件事**：导出加 `\uFEFF` BOM（否则 Excel 中文乱码）；含逗号/引号的字段要 `"..."` 且内部 `"` 翻倍；导入按**表头别名**匹配列（`品名/名称/name/商品`），别按列序写死。
- **导入分两种语义并明确写进确认框**：CSV = 追加（合并），JSON 备份 = 覆盖。写错一次就是用户数据没了。
- **数据类用「导出备份 / 导入备份」而不是 artboard 那套工程文件**：用户要的是数据可搬走，不是把界面也搬走；JSON 小得多，也方便他们自己改。
- 实测数字：2000 条 CSV 导入 + 落库 + 渲染 **1.5 秒**；单条增删改 <250ms；4000×3000 图片处理为 1600px 长边 **约 2.7 秒/张**（桌面）。
