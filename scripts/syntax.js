#!/usr/bin/env node
/* 语法预检：把 html 里每个 <script> 用 vm 编译一遍，报出文件行号列号。
   用法：node syntax.js <file.html>   （开浏览器之前先跑这个，30 秒省掉两轮返工）
   退出码：0 通过，1 有语法错误，2 用法错误 */
const fs = require('node:fs');
const vm = require('node:vm');
const f = process.argv[2];
if (!f || !fs.existsSync(f)) { console.log('用法: node syntax.js <file.html>'); process.exit(2); }
const html = fs.readFileSync(f, 'utf8');
const lineOf = (pos) => html.slice(0, pos).split('\n').length;
const re = /<script\b([^>]*)>([\s\S]*?)<\/script>/gi;
let m, idx = 0, bad = 0;
while ((m = re.exec(html))) {
  idx++;
  const attrs = m[1] || '', code = m[2] || '';
  if (/\bsrc\s*=/i.test(attrs)) { console.log(`script #${idx}: 外链脚本（离线单文件不允许） 第 ${lineOf(m.index)} 行`); bad++; continue; }
  if (/type\s*=\s*["']?(application\/json|text\/template)/i.test(attrs)) { console.log(`script #${idx}: 数据块，跳过`); continue; }
  if (!code.trim()) { console.log(`script #${idx}: 空`); continue; }
  const openTag = m[0].slice(0, m[0].indexOf('>') + 1);
  const base = lineOf(m.index + openTag.length);
  try {
    new vm.Script(code, { filename: 'inline' });
    console.log(`script #${idx}: OK（${code.length} 字符）`);
  } catch (e) {
    const at = /inline:(\d+)(?::(\d+))?/.exec(e.stack || '') || [];
    const sl = at[1] ? Number(at[1]) + base - 1 : null;
    console.log(`script #${idx}: 语法错误 ${e.message}` + (sl ? `  → 文件第 ${sl} 行` + (at[2] ? ` 第 ${at[2]} 列` : '') : ''));
    if (!at[1]) console.log('   原始位置信息: ' + String(e.stack || '').split('\n')[0]);
    if (sl) for (let i = Math.max(0, sl - 3); i < Math.min(html.split('\n').length, sl + 1); i++)
      console.log('   ' + (i + 1) + '| ' + html.split('\n')[i].trim().slice(0, 120));
    bad++;
  }
}
console.log(bad ? `--- ${bad} 个脚本块有问题，先修完再开浏览器 ---` : '--- 语法全部通过 ---');
process.exit(bad ? 1 : 0);
