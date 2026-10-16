#!/bin/bash
cd "$(dirname "$0")"
ulimit -v ${CRAWL_MEM_KB:-3000000}
mkdir -p crawlout
rm -f crawlout/*.txt
{
	echo demo
	luau crawl.luau -a list > crawlout/list.lst
	awk '/^SUB /{ sub(/^SUB /, ""); split($0, a, "/"); has[a[1]] = 1; print "demo:" $0 } /^SECTION /{ sub(/^SECTION /, ""); secs[++n] = $0 } END { for (i = 1; i <= n; i++) if (!has[secs[i]]) print "demo:" secs[i] }' crawlout/list.lst
	for t in metrics debuglog idstack style about userguide; do echo $t; done
	for a in MainMenuBar Console Log Layout PropertyEditor LongText AutoResize ConstrainedResize SimpleOverlay Fullscreen WindowTitles CustomRendering Documents AssetsBrowser ImageViewer; do echo app:ShowExampleApp$a; done
} > crawlout/targets.lst
one() { tag=$(echo "$1" | tr ' /:&' '____'); timeout -s KILL ${CRAWL_TIMEOUT:-900} stdbuf -oL luau crawl.luau -a "$1" > "crawlout/$tag.txt" 2>&1 || echo "KILLED/EXIT $? target=$1" >> "crawlout/$tag.txt"; grep -E "^SUMMARY|^KILLED" "crawlout/$tag.txt" | tail -1; }
export -f one
tr '\n' '\0' < crawlout/targets.lst | xargs -0 -P ${P:-3} -I{} bash -c 'one "$1"' _ {}
echo "== failures"
grep -hE "^SIG" crawlout/*.txt | sed 's/^SIG [0-9]*x //' | sort | uniq -c | sort -rn
grep -lE "^FAIL|^KILLED" crawlout/*.txt
awk '/^SUMMARY/ { for (i = 1; i <= NF; i++) { split($i, kv, "="); s[kv[1]] += kv[2] } n++ } END { printf "TOTAL targets=%d items=%d actions=%d popups=%d frames=%d fails=%d\n", n, s["items"], s["actions"], s["popups"], s["frames"], s["fails"] }' crawlout/*.txt
