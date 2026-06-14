#!/usr/bin/env bash
# coverage.sh - Flutter test coverage measurement for book-review-app
#
# Usage: ./scripts/coverage.sh
#
# Prerequisites:
#   - lcov package installed (sudo apt-get install -y lcov)
#   - Flutter SDK available
#
# Steps:
#   1. flutter pub get
#   2. flutter test --coverage
#   3. genhtml coverage/lcov.info -o coverage/html
#   4. lcov --summary coverage/lcov.info

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "==> Step 1: flutter pub get"
flutter pub get

echo ""
echo "==> Step 2: flutter test --coverage"
flutter test --coverage

echo ""
echo "==> Step 3: genhtml coverage/lcov.info -o coverage/html"
genhtml coverage/lcov.info -o coverage/html

echo ""
echo "==> Step 4: lcov --summary coverage/lcov.info"
lcov --summary coverage/lcov.info

echo ""
echo "Done. Open coverage/html/index.html to view the report."
