#!/usr/bin/env bash
# 把 git hooks 指向 scripts/hooks/，让 pre-push 自动跑 smoke。
# 一次性执行；git config 写在本仓库 .git/config（不影响其它仓库）。

set -e
cd "$(git rev-parse --show-toplevel)"

chmod +x scripts/hooks/pre-push
git config core.hooksPath scripts/hooks

echo "[install_hooks] core.hooksPath -> scripts/hooks"
echo "[install_hooks] pre-push 已生效。下次 git push 会先跑 ./scripts/smoke.sh"
echo "[install_hooks] 紧急绕过：git push --no-verify"
