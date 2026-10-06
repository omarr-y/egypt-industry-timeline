#!/bin/bash
# Builds EgyptIndustry.ipa for AltStore. AltStore signs it with your free Apple ID,
# so no signing setup is needed in Xcode.
#
# Usage: put this file in the folder that contains EgyptIndustry.xcodeproj, then in Terminal:
#   cd path/to/that/folder
#   bash build-ipa.sh
set -e

PROJECT="EgyptIndustry"

echo "Building $PROJECT (this takes a minute or two the first time)..."
xcodebuild \
  -project "$PROJECT.xcodeproj" \
  -scheme "$PROJECT" \
  -configuration Release \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  -quiet

APP="build/Build/Products/Release-iphoneos/$PROJECT.app"
if [ ! -d "$APP" ]; then
  echo "Build finished but $APP was not found." >&2
  exit 1
fi

rm -rf Payload "$PROJECT.ipa"
mkdir Payload
cp -R "$APP" Payload/
zip -qry "$PROJECT.ipa" Payload
rm -rf Payload

echo ""
echo "Done: $(pwd)/$PROJECT.ipa"
echo "Send it to your iPhone (AirDrop is easiest), then open it with AltStore."
