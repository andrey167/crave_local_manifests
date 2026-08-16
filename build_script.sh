#!/usr/bin/env bash

########################################
# SOURCE SETUP
########################################

echo "==> Resetting manifests..."
rm -rf .repo/local_manifests

echo "==> Initializing repo..."
repo init -u https://github.com/AndroidOne-Experience/manifest.git -b 15 --depth=1 --git-lfs
git clone https://github.com/andrey167/crave_local_manifests -b aosp-15 .repo/local_manifests

########################################
# SYNC SOURCE
########################################

echo "==> Syncing source..."
/opt/crave/resync.sh
/opt/crave/resync.sh
/opt/crave/resync.sh

########################################
# BUILD SETUP
########################################

echo "==> Preparing environment..."
. build/envsetup.sh

export BUILD_USERNAME=andrey
export BUILD_HOSTNAME=crave
export TZ=Asia/Jakarta
export KBUILD_USERNAME="$BUILD_USERNAME"
export KBUILD_HOSTNAME="$BUILD_HOSTNAME"
sed -i 's/tm.getModemService()/""/g' \
packages/services/Telephony/src/com/android/phone/CarrierConfigLoader.java
grep -n "modemService" packages/services/Telephony/src/com/android/phone/CarrierConfigLoader.java

git clone https://github.com/andrey167/platinakeys vendor/evolution-priv/keys

grep -q "vendor/evolution-priv/keys/keys.mk" device/xiaomi/platina/BoardConfig.mk || sed -i '$ a -include vendor/evolution-priv/keys/keys.mk' device/xiaomi/platina/aosp_platina.mk
#sed -i 's/PRODUCT_CERTIFICATE_OVERRIDES/PRODUCT_PACKAGE_NAME_OVERRIDES/g' vendor/evolution-priv/keys/keys.mk
tail -5 device/xiaomi/platina/aosp_platina.mk

echo "==> Lunching target..."
lunch aosp_platina-bp1a-user

echo "==> Cleaning previous build outputs..."
m installclean
mka bacon

########################################
# UPLOAD AND CLEANUP
########################################

ZIP_FILE=$(ls -t out/target/product/platina/AndroidOne*.zip 2>/dev/null | head -n 1)

if [ -n "$ZIP_FILE" ] && [ -f "$ZIP_FILE" ]; then
    echo "==> Build finished! Uploading $ZIP_FILE to GoFile..."

    SERVER_RESP=$(curl -s https://api.gofile.io/servers)
    SERVER=$(echo "$SERVER_RESP" | grep -o '"name":"[^"]*' | head -n 1 | cut -d'"' -f4)

    if [ -z "$SERVER" ]; then
        echo "==> ERROR: Failed to get GoFile server!"
        echo "Response: $SERVER_RESP"
        exit 1
    fi

    echo "==> Using GoFile server: $SERVER"

    UPLOAD_RES=$(curl -# -F "file=@$ZIP_FILE" "https://${SERVER}.gofile.io/contents/uploadfile")

    IS_SUCCESS=$(echo "$UPLOAD_RES" | grep -o '"status":"ok"')

    if [ -n "$IS_SUCCESS" ]; then
        # 
        DOWNLOAD_PAGE=$(echo "$UPLOAD_RES" | grep -o '"downloadPage":"[^"]*' | cut -d'"' -f4)

        echo ""
        echo "=================================================="
        echo "DOWNLOAD LINK: $DOWNLOAD_PAGE"
        echo "=================================================="
    else
        echo ""
        echo "==> UPLOAD FAILED!"
        echo "Server Response: $UPLOAD_RES"
    fi
else
    echo "==> ERROR: Zip file not found in out/target/product/platina/"
fi

echo "==> All tasks completed successfully!"
