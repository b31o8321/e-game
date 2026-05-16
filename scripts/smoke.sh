#!/usr/bin/env bash
# 全流程 smoke test — 推送前的最后防线。
# 跑：tests/test_smoke_full_flow.gd 全流程 + tests/test_per_floor_deck_isolation.gd 黑/白盒交叉。
# 调用方式：./scripts/smoke.sh
# 失败 → 非 0 退出码，可在 pre-push hook 里挂。

set -e
cd "$(dirname "$0")/.."

GODOT_BIN="${GODOT_BIN:-godot}"

echo "[smoke] Running full-flow + isolation smoke tests..."
echo

OUT=$(
"$GODOT_BIN" --headless \
  -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/test_smoke_full_flow.gd,res://tests/test_per_floor_deck_isolation.gd \
  -gexit 2>&1
)

echo "$OUT" | tail -25

# GUT 不在 exit code 上反映失败 —— 抓"Failing Tests"或"failing tests"行
if echo "$OUT" | grep -Eq "Failing Tests +[1-9]|---- [1-9]+ failing tests"; then
  echo
  echo "[smoke] FAIL — see above"
  exit 1
fi

echo
echo "[smoke] PASS"
