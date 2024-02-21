#!/bin/bash

[ -z "$ZIP" ] && return 1
[ -z "$REPOURL" ] && return 1

METADATA=$(unzip -p "$ZIP" META-INF/com/android/metadata)

# this doesnt generate new timestamps on dirty builds
#TIMESTAMP=$(grep post-timestamp <<< "$METADATA" | cut -f2 -d'=')
# instead we just use the file modified timestamp
TIMESTAMP=$(stat -c %Y "$ZIP")

DEVICE=$(grep pre-device <<< "$METADATA" | cut -f2 -d'=' | cut -f1 -d',')
SDK_LEVEL=$(grep post-sdk-level <<< "$METADATA" | cut -f2 -d'=')
FILENAME=$(basename "$ZIP")
ROMTYPE=$(cut -f4 -d'-' <<< "$FILENAME")
VERSION=$(cut -f2 -d'-' <<< "$FILENAME")
SIZE=$(du -b "$ZIP" | cut -f1 -d$'\t')
ID=$(sha256sum <<< "${TIMESTAMP}${DEVICE}${SDK_LEVEL}${ROMTYPE}${VERSION}${SIZE}" | cut -f1 -d' ')

RELEASENAME="$DEVICE-$VERSION-$(date -d '@'${TIMESTAMP} +%Y%m%d%H%M%S)"
OTAURL="$REPOURL/releases/download/$RELEASENAME/$FILENAME"
RECOVERY_NAME=$(sed -e 's/UNOFFICIAL/recovery/' -e 's/\.zip$/.img/' <<< "$FILENAME")
