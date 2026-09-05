#!/usr/bin/env bash
# Route mix · outcomes · cap-hit rate · spend, from .claude/routing-log.md
awk -F'|' 'NR>1 && NF>=9 {
  gsub(/ /,"",$3); n[$3]++; cost+=$8+0
  if ($9 ~ /done/) ok++; if ($9 ~ /cap/) caps++
  t++ }
END { for (r in n) printf "%-9s %d\n", r, n[r]
  printf "tasks:%d done:%d cap-hits:%d (%.0f%%) spend:$%.2f\n", t, ok, caps, t?100*caps/t:0, cost }' \
  .claude/routing-log.md
