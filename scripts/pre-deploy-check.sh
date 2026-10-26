#!/bin/bash
# ⛩️ Pre-deploy check — デプロイ前に CI 同等の全チェックをローカル実行
# book-review-app 専用：pub get → analyze → 全量 test (TZ=UTC)
# 八百万の掟：デプロイ前には必ずこのスクリプトを通せ
# 注: ビルド(fastlane)は含めない。Deploy ワークフローは branches: [never-main-disabled] で意図的に無効。
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

export PATH="/tmp/flutter/bin:$PATH"
# CI は UTC。JST 前提の時限爆弾をローカルで検出するため固定する。
export TZ=UTC

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⛩️  Pre-deploy check: book-review-app"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# --- Step 1: flutter pub get ---
echo ""
echo "[1/3] 📦 flutter pub get..."
flutter pub get
echo "✅ pub get OK"

# --- Step 2: flutter analyze ---
echo ""
echo "[2/3] 🔍 flutter analyze --no-fatal-infos..."
flutter analyze --no-fatal-infos
echo "✅ analyze OK (no warnings or errors)"

# --- Step 3: 全量テスト (CI と同じ UTC) ---
echo ""
echo "[3/3] 🧪 flutter test (全量, TZ=UTC)..."
flutter test --no-pub --reporter compact test
echo "✅ test passed"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Pre-deploy check PASSED — safe to deploy"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
