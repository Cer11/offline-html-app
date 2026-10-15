#!/usr/bin/env bash
# 发布前体检：bash audit.sh <单个 html 文件>
# 只检查会影响「双击就能用 / 断网能用 / 手机能开 / 打印导出正确」的项。
# FAIL = 必须修；WARN = 建议修；---- = 本形态不需要。退出码非 0 表示有 FAIL。
#
# 应用形态（决定检查项），在文件里显式声明最准：
#   <!-- profile: artboard -->  固定画布、导出图片/打印一页（菜单、海报、标签、名片）
#   <!-- profile: data -->      列表/记录类，本地数据库 + 导入导出（台账、库存、名单）
#   <!-- profile: tool -->      一次性处理工具，输入文件→输出文件（图片批处理、格式转换）
# 不声明就自动猜：调了 html2canvas 或有 #board 画布 → artboard，否则 data。
f="$1"
if [ -z "$f" ] || [ ! -f "$f" ]; then echo "用法: bash audit.sh <file.html>"; exit 2; fi
fail=0; warn=0
cnt(){ grep -c -F -- "$1" "$f" 2>/dev/null | head -1; }
cntre(){ grep -c -E -- "$1" "$f" 2>/dev/null | head -1; }
chk(){ local lvl="$1" c="$2" want="$3" msg="$4" fix="$5" hit=0
  [ "${c:-0}" != "0" ] && hit=1
  if [ "$hit" = "$want" ]; then printf 'PASS  %s\n' "$msg"
  elif [ "$lvl" = "FAIL" ]; then printf 'FAIL  %s\n      → %s\n' "$msg" "$fix"; fail=$((fail+1))
  else printf 'WARN  %s\n      → %s\n' "$msg" "$fix"; warn=$((warn+1)); fi; }

sz=$(( $(wc -c < "$f") / 1024 ))
prof=$(grep -o -E '<!--[[:space:]]*profile:[[:space:]]*(artboard|data|tool)' "$f" | grep -o -E 'artboard|data|tool' | head -1)
if [ -z "$prof" ]; then
  if [ "$(cntre 'html2canvas\(')" != "0" ] || [ "$(cnt 'id="board"')" != "0" ]; then prof=artboard; else prof=data; fi
fi
echo "=== $(basename "$f")  ${sz} KB  形态=${prof}（可用 <!-- profile: artboard|data|tool --> 指定）==="

# ---------- 语法（有 node 就查；没有就必须先加载一次页面看控制台） ----------
if command -v node >/dev/null 2>&1; then
  if node "$(dirname "$0")/syntax.js" "$f" >/dev/null 2>&1; then echo "PASS  内联脚本语法检查"; else
    echo "FAIL  内联脚本语法错误（整页会白屏）"; node "$(dirname "$0")/syntax.js" "$f" | grep 'ERR' | sed 's/^/      /'
    fail=$((fail+1)); fi
else
  echo "----  语法预检跳过（本机没有 node）：务必先加载一次页面并读控制台，语法错误会让整页白屏"
fi

# ---------- 通用 ----------
chk FAIL "$(cntre 'src="https?://')"  0 "无外链脚本/图片"   "下载后转 data: URI 内联，见 references/packaging.md"
chk FAIL "$(cntre 'href="https?://')" 0 "无外链样式/字体"   "同上；断网时必须还能用"
chk FAIL "$(cnt '@import')"           0 "无远程 @import"     "远程字体在无网/微信里会白屏"
chk FAIL "$(cnt 'user-scalable=no')"  0 "未禁用双指缩放"     "手机屏比画布窄，禁了就没法看清细节"
chk FAIL "$(cnt 'maximum-scale')"     0 "未限制最大缩放"     "同上"
chk FAIL "$(cnt 'text-size-adjust')"  1 "text-size-adjust:100%" "缺了 iOS Safari 可能自动放大字号打乱排版"
chk FAIL "$(cnt 'id="nojs"')"         1 "有「未启用 JS」兜底说明" "微信直接点开/快速预览不跑 JS，用户只会看到白屏"
chk FAIL "$(cnt 'confirm(')"          0 "未用原生 confirm"   "微信等内核经常吞掉原生对话框，等于没有二次确认；改用页面内弹窗"
chk FAIL "$(cnt 'alert(')"            0 "未用原生 alert"     "同上"
chk WARN "$(cntre '[?][.][a-zA-Z_]')" 0 "未使用可选链 ?."    "Chrome<80 / iOS<13.4 直接语法报错，整个文件打不开"
chk WARN "$(cnt '??')"                0 "未使用空值合并 ??"  "同上"
# localStorage 必须被 try 包住（iOS 本地文件 / 无痕模式会直接抛异常）
chk FAIL "$(cntre 'try\{[^}]{0,80}localStorage|localStorage[^;]{0,80}catch|catch\(e\)\{[^}]{0,40}(return (null|false)|toast)')" 1 \
  "localStorage 访问被 try 包住" "iOS Safari/无痕模式直接访问会抛异常并中断启动"

# ---------- 按形态 ----------
case "$prof" in
 artboard)
  chk FAIL "$(cntre 'html2canvas [0-9]+\.[0-9]+')" 1 "html2canvas 已内联" "导出图片不可用；见 packaging.md 下载与内联步骤"
  chk FAIL "$(cnt '@media print')"      1 "有打印样式"             "隐藏工具条/弹层，别让按钮印到纸上"
  chk FAIL "$(cnt '@page')"             1 "有 @page 纸张尺寸"      "不写 size 时横版会被塞进纵向纸"
  chk FAIL "$(cnt 'zoom:')"             1 "打印时按纸张缩放画布"   "画布 CSS px 大于 A4 物理尺寸，不缩就溢到第 2 页"
  chk FAIL "$(cnt 'print-color-adjust')" 1 "print-color-adjust:exact" "浏览器打印默认丢弃背景图和背景色"
  chk FAIL "$(cnt 'toBlob')"            1 "导出有 toBlob 路径"     "老 Safari/部分安卓内核没有 toBlob，需要 dataURL 兜底"
  chk WARN "$(cntre '_v[0-9]')"         1 "存储 key 带版本号"       "结构变更后老用户读到旧数据，表现为「改了没生效」"
  chk WARN "$(cnt 'application/json')"  1 "支持把状态嵌回自身（工程文件）" "否则内容带不到别的设备"
  ;;
 data)
  chk FAIL "$(cnt 'indexedDB')"         1 "用 IndexedDB（或明确退回 localStorage）" "localStorage 只有 5MB，记录一多就写爆"
  chk FAIL "$(cntre 'onerror=|catch\(e\)')" 1 "IndexedDB 失败有退路" "iOS 本地文件里 IDB 可能被禁，要能退回并提示"
  chk FAIL "$(cnt '@page')"             1 "有 @page 纸张尺寸"      "列表打印也要指定 A4，否则被塞进默认纸"
  chk WARN "$(cnt '@media print')"      1 "有打印样式"             "隐藏工具条，列表用自然分页（不要套画布那套 zoom）"
  chk WARN "$(cntre '\.slice\(|limit=|PAGE')" 1 "列表有分页/截断"   "几千行一次塞进 DOM，手机会卡死或被系统杀掉"
  chk WARN "$(cntre '\uFEFF')" 1 "CSV 导出带 BOM"      "没有 BOM 时 Excel 打开中文乱码"
  chk WARN "$(cntre '_v[0-9]')"         1 "存储 key 带版本号"       "结构变更后老用户读到旧数据"
  ;;
 tool)
  chk FAIL "$(cnt 'revokeObjectURL')"   1 "用完释放 objectURL"     "批量图片不释放会内存泄漏，手机上直接崩"
  chk WARN "$(cntre '16000000|MAXPX|16M')" 1 "限制画布总像素"       "iOS 画布约 16.7M px 上限，超了导出为空"
  chk WARN "$(cnt 'multiple')"          1 "文件输入支持多选"       "批处理工具的本职"
  chk WARN "$(cntre 'dataTransfer')"    1 "支持拖放"               "桌面端主要交互"
  ;;
esac
if [ "$sz" -gt 8192 ]; then warn=$((warn+1)); echo "WARN  文件 ${sz} KB 超过 8MB，微信传输/手机打开会吃力"; echo "      → 压缩内联图片；大模型（OCR/语音）不适合单文件"; fi
echo "---"
if [ "$fail" = "0" ]; then echo "结论：可以发布（FAIL 0，WARN $warn）"; else echo "结论：不能发布，$fail 项 FAIL 必须先修"; fi
exit $((fail>0 ? 1 : 0))
