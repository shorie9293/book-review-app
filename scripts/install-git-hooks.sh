#!/bin/bash
# ⛩️ Git フック設置 — scripts/pre-push を .git/hooks/pre-push へ複写する
# .git/hooks は非追跡ゆえ、正本は scripts/pre-push に置く。
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

cp scripts/pre-push .git/hooks/pre-push
chmod +x .git/hooks/pre-push

echo "✅ 設置完了: $REPO_ROOT/.git/hooks/pre-push"
echo "   正本: $REPO_ROOT/scripts/pre-push"
