#!/usr/bin/env node
/* A4 / 打印尺寸换算：设计画布 CSS px、导出 scale、落纸毫米、打印 zoom、出血
   用法：node a4.js [宽mm] [高mm] [设计dpi=150] [打印dpi=300] [出血mm=0]
   例：  node a4.js 210 297            → A4 竖版
         node a4.js 297 210            → A4 横版
         node a4.js 210 285 150 300 3  → 大16开 + 3mm 出血 */
const mm = Number(process.argv[2] || 210);
const mh = Number(process.argv[3] || 297);
const dpi = Number(process.argv[4] || 150);
const pdpi = Number(process.argv[5] || 300);
const bleed = Number(process.argv[6] || 0);
const r = (n) => Math.round(n * 10) / 10;
const r3 = (n) => Math.round(n * 1000) / 1000;
const toPx = (m, d) => Math.round((m / 25.4) * d);
const bw = toPx(mm + bleed * 2, dpi), bh = toPx(mh + bleed * 2, dpi);
const scale = r3(pdpi / dpi);
const ex = Math.round(bw * (pdpi / dpi)), ey = Math.round(bh * (pdpi / dpi));
const zoom = r3(((mm + bleed * 2) / 25.4 * 96) / bw);
const lines = [
  `纸张        ${mm}×${mh} mm${bleed ? `　出血 ${bleed} mm/边 → 成纸 ${mm + bleed * 2}×${mh + bleed * 2} mm` : ''}`,
  `设计画布    ${bw}×${bh} CSS px（${dpi}dpi）　← 写进 #board 的 width/height`,
  `导出        scale ${scale} → ${ex}×${ey} px（${pdpi}dpi）`,
  `落纸        ${r3(ex / pdpi * 25.4)}×${r3(ey / pdpi * 25.4)} mm`,
  `打印 zoom   ${zoom}　建议写 ${r3(zoom - 0.002)}（略小一点，避免四舍五入溢出到第 2 页）`,
  `换算        1 CSS px = ${r3(25.4 / dpi)} mm　1 mm = ${r3(dpi / 25.4)} px@${dpi}dpi`,
  `出图给 AI   画布上任意 N px 的元素，素材按 N×${scale} 的像素出（${pdpi}dpi 不模糊）`,
];
if (ex * ey > 16700000) lines.push('!! 警告：导出像素超过 16.7M（iOS Safari 画布上限），手机可能导出失败，请降 dpi 或保留 1 倍重试');
if (zoom > 1) lines.push('!! 注意：zoom>1 说明设计 dpi 低于 96dpi 换算，打印会被放大，检查 dpi 参数');
console.log(lines.join('\n'));
