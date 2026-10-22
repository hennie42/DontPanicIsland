#!/usr/bin/env bash
# tools/deploy_pages.sh [--no-export]: export the web build (studio godot-export web) and publish build/web to the
# gh-pages branch of origin (GitHub Pages serves it at https://hennie42.github.io/DontPanicIsland/).
# The branch is worked on in a separate worktree under out/pages; the main branch never contains the build.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ${1:-} != --no-export ]]; then
  studio godot-export web | tail -2
fi
[[ -f build/web/index.html && -f build/web/index.wasm ]] || { echo "no web build in build/web"; exit 1; }
src=$(git rev-parse --short HEAD)
wt=out/pages
git fetch origin gh-pages 2>/dev/null || true
if [[ ! -d $wt/.git && ! -f $wt/.git ]]; then
  rm -rf "$wt"
  if git show-ref --quiet refs/remotes/origin/gh-pages; then
    git worktree add -B gh-pages "$wt" origin/gh-pages
  else
    git worktree add --detach "$wt"
    git -C "$wt" checkout --orphan gh-pages
    git -C "$wt" rm -rfq . || true
  fi
fi
find "$wt" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -r build/web/. "$wt"/
touch "$wt/.nojekyll"
git -C "$wt" add -A
if git -C "$wt" diff --cached --quiet; then
  echo "gh-pages already up to date"
else
  git -C "$wt" commit -qm "Web build of $src"
fi
git -C "$wt" push origin gh-pages
echo "published $src -> https://hennie42.github.io/DontPanicIsland/"
