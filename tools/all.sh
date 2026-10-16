#!/bin/bash
cd "$(dirname "$0")"
ulimit -v ${MEM_KB:-3000000}
fail=0
run() { if ! timeout 600 luau run.luau -a "$@" 2>&1 | grep -E "^PASS" ; then echo "FAIL $*"; fail=1; fi; }
run basic 30
run openall 30 1 big
run openall 30 1
for s in 1 2 3 4 5; do run fuzz 600 $s; done
for s in 1 2 3 4 5; do run fuzzall 600 $s; done
for s in 1 2 3; do run fuzzall 300 $s big; done
exit $fail
