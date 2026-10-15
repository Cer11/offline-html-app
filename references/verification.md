# 数值化验收：每个变体都要过

**"0 控制台报错"不等于通过。** 这类应用的失败模式几乎都是静默的：改了没写回、导出是空白图、打印多一页、某栏溢出 400px、字体漏字。只有量出来的数字能证明它对了。

三个层次的证据要分开写，别混：① 读代码/静态检查 ② 浏览器里跑真实 UI 路径 ③ 真机（用户手机/真打印机）。只有 ② 能自动化，③ 只能请用户验。

## 探针清单

用浏览器自动化（Tabbit CLI 的 `nodejs`，或 browser-use 的 `evaluate_script`）跑下面这些。**必须点真实按钮**，不要直接调内部函数——真实路径才能覆盖 `imgTarget`、事件绑定这些出过事的地方。

```js
// ① 溢出：内容有没有超出画布
const cols=document.getElementById('cols');
const fits=cols.scrollHeight<=cols.clientHeight;
const sums=[...cols.querySelectorAll('.col')].map(c=>{let s=0;
  c.querySelectorAll('.b-sec').forEach(b=>s+=b.offsetHeight+19);return s;});

// ② 节奏：图片位之间的间距是不是均匀（用户会一眼看出"粘在一起"）
const sqs=[...document.querySelectorAll('.b-sec .sq')].map(e=>e.getBoundingClientRect());
const gaps=sqs.map((r,i)=>i?Math.round(r.top-sqs[i-1].bottom):-1).filter(v=>v>=0);

// ③ 文字裁切
const clipped=[...document.querySelectorAll('.n,.t,.tx')]
  .filter(e=>e.scrollWidth>e.clientWidth+1).map(e=>e.textContent.slice(0,12));

// ④ 导出：点真按钮，读回真实像素，再采样判断"不是空白"
document.getElementById('bPng').click();
// 等 #pv img 出现后：
const im=document.querySelector('#pv img');
const c=document.createElement('canvas');c.width=im.naturalWidth*.2;c.height=im.naturalHeight*.2;
const g=c.getContext('2d');g.drawImage(im,0,0,c.width,c.height);
const d=g.getImageData(0,0,c.width,c.height).data;
let ink=0;const pal=new Set();
for(let k=0;k<d.length;k+=4){const r=d[k],q=d[k+1],b=d[k+2];
  if(r<246||q<245||b<238)ink++;pal.add((r>>3)+','+(q>>3)+','+(b>>3));}
// ink%、pal、im.naturalWidth+'x'+naturalHeight 三项一起报

// ⑤ 打印：切到打印媒体再量落纸尺寸
await page.emulateMedia({media:'print'});
const r=document.getElementById('board').getBoundingClientRect();
const mm=[r.width*0.264583, r.height*0.264583];   // A4 竖版应约 209.3×296.1

// ⑥ 工程文件往返
const h=window.__app.projectHTML();
const back=window.__app.extractState(h);
JSON.stringify(back)===JSON.stringify(window.__app.state);   // true
(h.match(/src="https?:\/\//g)||[]).length;                   // 0

// ⑦ 手机视口
await page.setViewportSize({width:390,height:844});
document.documentElement.scrollWidth===window.innerWidth;    // 不横向溢出
// 弹层：getBoundingClientRect() 完整落在视口内；按钮高 ≥44；输入框 font-size ≥16px
```

## 换图 / 确认框也要走真路径

```js
// 真文件选择器：先挂等待，再点按钮
const w=page.waitForEvent('filechooser',{timeout:10000}).then(f=>f.setFiles('C:/…/test.jpg'));  // 路径用正斜杠
await page.evaluate(()=>{document.querySelector('.b-mast').click();
  [...document.querySelectorAll('#sheet .acts .btn')].find(b=>/选择图片/.test(b.textContent)).click();});
await w;
// 断言：state 里那张图变了、且不再是内置默认图
```

二级确认必须验三条：**取消后数据没变**、**确认后生效**、**撤销能回退**。只验"确认能用"是不够的——它的主要职责是防误触。

## 参考阈值

| 指标 | 通过线 |
| --- | --- |
| 导出像素 | 与 `a4.js` 算出的一致（A4 竖版 300dpi＝2480×3508） |
| 导出 ink% | 纯白底文档 20–40%；带整页底图 80–96%；<5% 基本就是空白图 |
| 导出颜色数 | >150（低于此多半是纯色块/没渲染） |
| 栏高差 | 多栏排版最高栏 ≤ 可用高；栏间内容差建议 <25% |
| 图片位间距 | 同一列内相邻间距极差 ≤4px，否则会被判"不齐/粘在一起" |
| 触摸目标 | 主操作（保存/取消/确认）≥44px；工具条按钮 ≥32px |
| 文字裁切 | 0 个元素 scrollWidth>clientWidth |
| 打印落纸 | 每边留 0.2–1mm 余量，绝不超 210/297 |
| 工程文件 | 往返 deep-equal；体积 ≈ 模板体积（默认图不能存两遍） |

## 环境注意

- **隐藏页 / 零尺寸视口不可用于视口相关结论**：某些自动化通道里 `window.innerWidth===0`，`fit()` 会被 clamp 到最小值，此时"缩放对不对""是否溢出屏幕"都测不准；但画布内部布局（固定 px）仍然有效。要测视口相关，用真实窗口（Tabbit）并显式 `setViewportSize`。
- 截图看观感，**结论下在数字上**。改一处样式就重跑整套：每个变体（横版/竖版/深浅/固定或随内容）都要单独导出验一次，不要"改的是横版所以竖版应该没事"。
- 交付前跑 `bash scripts/audit.sh <成品.html>`，FAIL 必须清零。

## 报告口径

跟用户说结果时，把"实测到的"和"没条件验的"分开：例如「打印已用 Chrome 打印媒体模拟验过正好一页，实体打印机没条件试」——这句话能省掉一轮返工和一次信任损失。

## 方法学教训（三个真实应用实测出来的）

1. **第 0 步是加载页面 + 读控制台，不是点按钮。** 内联脚本一个语法错误 = 整页白屏 = 所有交互测试都以 `waitForFunction 超时` 的形式失败，看起来像测试写错了。有 node 就先跑 `scripts/syntax.js`（直接给文件行号）；没有 node 就先读控制台。
2. **断言 computed style，不要只断言 DOM 存在。** 实测案例：helper 写成 `E('button','',…)` 让按钮丢了基类，CSS 选择器和 `querySelectorAll('.ops .btn')` 一起返回空——只断言"元素在"会一路绿灯。
3. **验证半透明叠加用同区域"开/关差值"，并且选对统计量。** 55% 透明度的白字压在亮背景上，区域均值几乎不动（实测 −1.5），用"白色像素占比"更是直接判 0。判位置对不对，最可靠的是对比"应在的区域"与"不应在的区域"（实测 193 vs 155）。
4. **改完文件重测要绕缓存。** `file://` 会被缓存，出现过"代码已修好、测试仍报旧行为"的假失败。加 `?v=N` 重新 goto 即可。
5. **列表类必须测分页与行数上限。** 2005 条一次进 DOM 时桌面重渲染 63ms 看似没事，手机上就是卡死点。断言 `tbody tr` 数量 ≤ 页面容量+1。
6. **手机要量"屏幕预算"。** 探针：`设置面板高 + 工具条高` 是否 < 视口高 45%。实测两个新应用都超了（634/844、406/844），内容区被挤没。
7. **响应式断点用 CSS 变形验证**：切窄屏后断言 `getComputedStyle(tr).display==='block'` 且 `td::before` 有内容。**不要**用"JS 判断视口渲染两套结构"的写法——resize 事件不总触发，实测出现过手机上仍是桌面表格。
8. **数据类还要测**：CSV 往返（含逗号/引号字段）逐字段相等、BOM 存在、导入前二级确认取消后数据不变、IndexedDB 不可用时能否退回 localStorage 继续记。
