#!/usr/bin/env bash

set +e
set +x

# Ensure repository is clean, and we're on the `public` branch:
echo "Making sure that repository is clean & checked out the public branch..." >&2
if [ ! -z "$(git status --porcelain)" ]; then
    echo "Git repository has uncommitted changes or untracked files, refusing!" >&2
    exit 1
fi

# This command requires git version 2.22.
if [ "$(git branch --show-current)" != "public" ]; then
    echo "Not on \"public\" branch!" >&2
    exit 1
fi

# Check that we've fetched the latest upstream changes:
echo "Making sure that this tree contains all upstream changes." >&2
git fetch github
if ! git merge-base --is-ancestor github/public HEAD; then
    echo "Ref github/public is not an ancestor of HEAD, refusing!" >&2
    exit 1
fi

echo "Building site..." >&2
nix-build --argstr gitRev "$(git rev-parse HEAD)" site.nix

while true; do
    read -p "Site built successfully, publish? " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

echo "Uploading site contents..." >&2
rsync -avL --checksum --no-times result/ root@am.mvpn.schuermann.io:/var/www/leon-schuermann-io/

echo "Tagging site & pushing to GitHub..." >&2
DEPLOY_TAG="$(date -u "+deploy-%Y%m%d-%H%M%S")"
git tag "$DEPLOY_TAG"
git push github "$DEPLOY_TAG"
git push github public:public
