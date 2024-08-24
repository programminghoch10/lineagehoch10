#!/bin/bash

set -e 
set -a
shopt -s lastpipe
#set -x

ZIP="$1"
[ -z "$ZIP" ] && echo "missing zip" && exit 1
ZIP="$(realpath "$ZIP")"
[ ! -f "$ZIP" ] && echo "couldnt locate zip" && exit 1

cd "$(dirname "$0")"

REPOURL=$(git remote get-url github || git remote get-url origin)
[ -z "$REPOURL" ] && echo "failed to find repo url" && exit 1
sed \
  -e 's|^http.*/\([^/]*\)/\([^/]*\)$|\1 \2|' \
  -e 's|^git@github\.com:\([^/]*\)/\([^/]*\)$|\1 \2|' \
  <<< "$REPOURL" | read REPOOWNER REPONAME
REPOURL="https://github.com/$REPOOWNER/$REPONAME"

[ ! -d "deploy" ] && echo "missing deploy branch checkout" && exit 1
(
    cd deploy
    git switch deploy
    git pull --ff-only
)

[ -f .gitauth ] && source .gitauth
[ -z "$GITHUB_TOKEN" ] && echo "missing github token" && exit 1

source collectotainfo.sh

# check if release already exists
! curl -L \
  -s \
  --fail \
  --output /dev/null \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN"\
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/$REPOOWNER/$REPONAME/releases/tags/$RELEASENAME" \
  || {
  echo "release $RELEASENAME already exists!" && exit 1
} 

envsubst < ota_template.json > deploy/"$DEVICE".json
GIT_COMMITMESSAGE="$(envsubst < ota_commitmessage.txt)"

cd deploy
git add "$DEVICE".json
git commit -m "$GIT_COMMITMESSAGE"
GIT_COMMITHASH=$(git log -1 --pretty=%H)
git push
cd ..

RELEASE_CREATE_REPONSE=$(curl -L \
  -X POST \
  --no-progress-meter \
  --fail \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN"\
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/$REPOOWNER/$REPONAME/releases" \
  -d "{
    \"target_commitish\": \"$GIT_COMMITHASH\",
    \"tag_name\": \"$RELEASENAME\"
}")
RELEASE_ID=$(jq -r '.id' <<< "$RELEASE_CREATE_REPONSE")

echo "filename = \"$FILENAME\""
FILENAME_URLENCODE=$(tr -d '\n' <<< "$FILENAME" | xxd -p | tr -d '\n' | sed 's/../%&/g')
# FILENAME_URLENCODE="$FILENAME"
curl -L \
  -X POST \
  --fail \
  --output /dev/stdout \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN"\
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -H "Content-Type: application/zip" \
  "https://uploads.github.com/repos/$REPOOWNER/$REPONAME/releases/$RELEASE_ID/assets?name=$FILENAME_URLENCODE" \
  --data-binary "@$ZIP"
