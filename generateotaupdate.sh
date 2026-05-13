#!/bin/bash

set -e 
set -a
set -u
shopt -s lastpipe
#set -x

ZIP="${1:-}"
[ -z "$ZIP" ] && echo "missing zip" && exit 1
ZIP="$(realpath "$ZIP")"
[ ! -f "$ZIP" ] && echo "couldnt locate zip" && exit 1

cd "$(dirname "$0")"

REPOURL=$(git remote get-url github || git remote get-url origin)
[ -z "$REPOURL" ] && echo "failed to find repo url" && exit 1
sed \
  -e 's|^http.*/\([^/]*\)/\([^/]*\)$|\1 \2|' \
  -e 's|^git@github\.com:\([^/]*\)/\([^/]*\)$|\1 \2|' \
  <<< "$REPOURL" | read -r REPOOWNER REPONAME
REPOURL="https://github.com/$REPOOWNER/$REPONAME"

[ ! -d "deploy" ] && echo "missing deploy branch checkout" && exit 1
(
    cd deploy
    git switch deploy
    git pull --ff-only
)

[ -f .gitauth ] && source .gitauth
[ -z "${GITHUB_TOKEN:-}" ] && echo "missing github token" && exit 1

source collectotainfo.sh

# check if release already exists
! curl \
  --fail \
  --silent \
  --location \
  --output /dev/null \
  --header "Accept: application/vnd.github+json" \
  --header "Authorization: Bearer $GITHUB_TOKEN"\
  --header "X-GitHub-Api-Version: 2026-03-10" \
  "https://api.github.com/repos/$REPOOWNER/$REPONAME/releases/tags/$RELEASENAME" \
  || {
  echo "Release $RELEASENAME already exists!" && exit 1
}

envsubst < ota_template.json > deploy/"$DEVICE".json
GIT_COMMITMESSAGE="$(envsubst < ota_commitmessage.txt)"

cd deploy
git add "$DEVICE".json
git commit -m "$GIT_COMMITMESSAGE"
GIT_COMMITHASH=$(git log -1 --pretty=%H)
git push
cd ..

RELEASE_CREATE_REPONSE=$(curl \
  --fail \
  --no-progress-meter \
  --location \
  --request POST \
  --header "Accept: application/vnd.github+json" \
  --header "Authorization: Bearer $GITHUB_TOKEN"\
  --header "X-GitHub-Api-Version: 2026-03-10" \
  "https://api.github.com/repos/$REPOOWNER/$REPONAME/releases" \
  --data "{
    \"target_commitish\": \"$GIT_COMMITHASH\",
    \"tag_name\": \"$RELEASENAME\",
    \"draft\": true
}")
RELEASE_ID=$(jq -r '.id' <<< "$RELEASE_CREATE_REPONSE")

echo "filename = \"$FILENAME\""
FILENAME_URLENCODE=$(tr -d '\n' <<< "$FILENAME" | xxd -p | tr -d '\n' | sed 's/../%&/g')
# FILENAME_URLENCODE="$FILENAME"
curl \
  --fail \
  --location \
  --request POST \
  --output /dev/null \
  --header "Accept: application/vnd.github+json" \
  --header "Authorization: Bearer $GITHUB_TOKEN"\
  --header "X-GitHub-Api-Version: 2026-03-10" \
  --header "Content-Type: application/zip" \
  "https://uploads.github.com/repos/$REPOOWNER/$REPONAME/releases/$RELEASE_ID/assets?name=$FILENAME_URLENCODE" \
  --data-binary "@$ZIP"

curl \
  --fail \
  --no-progress-meter \
  --location \
  --request PATCH \
  --output /dev/null \
  --header "Accept: application/vnd.github+json" \
  --header "Authorization: Bearer $GITHUB_TOKEN" \
  --header "X-GitHub-Api-Version: 2026-03-10" \
  "https://api.github.com/repos/$REPOOWNER/$REPONAME/releases/$RELEASE_ID" \
  --data "{\"draft\": false}"
