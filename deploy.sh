#!/usr/bin/env bash
# Run with the pinned tools using: nix run .#deploy
set -Eeuo pipefail

cd "$(git rev-parse --show-toplevel)"

# Ensure repository is clean, and we're on the `public` branch:
echo "Making sure that repository is clean & checked out the public branch..." >&2
if [ -n "$(git status --porcelain)" ]; then
  echo "Git repository has uncommitted changes or untracked files, refusing!" >&2
  exit 1
fi

# This command requires git version 2.22.
if [ "$(git branch --show-current)" != "public" ]; then
  echo 'Not on "public" branch!' >&2
  exit 1
fi

# Check that we've fetched the latest upstream changes:
echo "Making sure that this tree contains all upstream changes." >&2
git fetch github
if ! git merge-base --is-ancestor github/public HEAD; then
  echo "Ref github/public is not an ancestor of HEAD, refusing!" >&2
  exit 1
fi

echo "Making sure that the Nix files in tree are well formatted"
if ! treefmt --ci .; then
  echo 'treefmt --ci failed, fix formatting errors!' >&2
  exit 1
fi

echo "Building site..." >&2
build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT
nix build .#site --no-write-lock-file --option pure-eval true --out-link "$build_dir/result"

while true; do
  read -r -p "Site built successfully, publish? " yn
  case $yn in
  [Yy]*) break ;;
  [Nn]*) exit ;;
  *) echo "Please answer yes or no." ;;
  esac
done

echo "Uploading site contents..." >&2
rsync -avL --checksum --no-times "$build_dir/result/" 'root@[fd68:503a:ea05:b3da:34da:dbff:feb5:82a0]:/var/www/leon-schuermann-io/'

echo "Tagging site & pushing to GitHub..." >&2
DEPLOY_TAG="$(date -u "+deploy-%Y%m%d-%H%M%S")"
git tag "$DEPLOY_TAG"
git push github "$DEPLOY_TAG"
git push github public:public
