#!/bin/bash
# 导出网页版并发布到 gh-pages 分支（GitHub Pages 用）。
# 需要：已安装 Godot 4.7.2 和它的 Web 导出模板。
set -e
cd "$(dirname "$0")/.."
rm -rf export/web && mkdir -p export/web
godot --headless --export-release "Web" export/web/index.html
touch export/web/.nojekyll
TMP=$(mktemp -d)
git worktree add --detach "$TMP"
cd "$TMP"
git checkout --orphan gh-pages-new
git rm -rf -q . || true
cp -R "$OLDPWD/export/web/." .
git add -A
git commit -q -m "网页版 $(date +%Y-%m-%d)"
git push -f origin HEAD:gh-pages
cd - >/dev/null
git worktree remove --force "$TMP"
git branch -D gh-pages-new 2>/dev/null || true
echo "已发布到 gh-pages 分支"
