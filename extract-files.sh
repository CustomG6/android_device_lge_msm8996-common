#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$MY_DIR" ]]; then MY_DIR="$PWD"; fi

ANDROID_ROOT="$MY_DIR/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "$HELPER" ]; then
    echo "Unable to find helper script at $HELPER"
    exit 1
fi
. "$HELPER"

function blob_fixup() {
    case "${1}" in
    vendor/lib/hw/camera.msm8996.so)
        sed -i "s/service.bootanim.exit/service.bootanim.zzzz/g" "${2}"
        ;;
    vendor/lib64/libsettings.so)
        patchelf --replace-needed "libprotobuf-cpp-full.so" "libprotobuf-cpp-full-v28.so" "${2}"
        ;;
    vendor/lib64/libwvhidl.so)
        "${PATCHELF}" --replace-needed "libprotobuf-cpp-lite.so" "libprotobuf-cpp-lite-v29.so" "${2}"
        ;;
    vendor/lib/hw/vulkan.msm8996.so | vendor/lib64/hw/vulkan.msm8996.so)
        sed -i -e 's|vulkan.msm8953.so|vulkan.msm8996.so|g' "${2}"
        ;;

    # Move telephony packages to /system_ext
    system_ext/etc/init/dpmd.rc)
        sed -i "s/\/system\/product\/bin\//\/system\/system_ext\/bin\//g" "${2}"
        ;;

    # Move telephony packages to /system_ext
    system_ext/etc/permissions/com.qti.dpmframework.xml|system_ext/etc/permissions/dpmapi.xml|system_ext/etc/permissions/telephonyservice.xml)
        sed -i "s/\/system\/product\/framework\//\/system\/system_ext\/framework\//g" "${2}"
        ;;

    # Move telephony packages to /system_ext
    system_ext/etc/permissions/qcrilhook.xml)
        sed -i "s/\/product\/framework\//\/system\/system_ext\/framework\//g" "${2}"
        ;;

    # Move ims libs to product
    product/etc/permissions/com.qualcomm.qti.imscmservice.xml)
        sed -i -e 's|file="/system/framework/|file="/product/framework/|g' "${2}"
        ;;

    # Move qti-vzw-ims-internal permission to vendor
    vendor/etc/permissions/qti-vzw-ims-internal.xml)
        sed -i -e 's|file="/system/vendor/|file="/vendor/|g' "${2}"
        ;;

    # Provide shim for libdpmframework.so
    system_ext/lib64/libdpmframework.so)
        for  LIBCUTILS_SHIM in $(grep -L "libcutils_shim.so" "${2}"); do
            "${PATCHELF}" --add-needed "libcutils_shim.so" "$LIBCUTILS_SHIM"
        done
        ;;
    esac
}

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

while [ "$1" != "" ]; do
    case $1 in
        -n | --no-cleanup )     CLEAN_VENDOR=false
                                ;;
        -s | --section )        shift
                                SECTION="$1"
                                CLEAN_VENDOR=false
                                ;;
        * )                     SRC="$1"
                                ;;
    esac
    shift
done

if [ -z "$SRC" ]; then
    SRC=adb
fi

# Initialize the helper for common platform
setup_vendor "$PLATFORM_COMMON" "$VENDOR" "$ANDROID_ROOT" true $CLEAN_VENDOR

extract "$MY_DIR"/proprietary-files-qc.txt "$SRC" "$SECTION"
extract "$MY_DIR"/proprietary-files.txt "$SRC" "$SECTION"

# Initialize the helper for common device
setup_vendor "$DEVICE_COMMON" "$VENDOR" "$ANDROID_ROOT" true $CLEAN_VENDOR

extract "$MY_DIR/../$DEVICE_COMMON/proprietary-files.txt" "$SRC" "$SECTION"

# Reinitialize the helper for device
setup_vendor "$DEVICE" "$VENDOR" "$ANDROID_ROOT" false $CLEAN_VENDOR

extract "$MY_DIR/../$DEVICE/proprietary-files-qc.txt" "$SRC" "$SECTION"
extract "$MY_DIR/../$DEVICE/proprietary-files.txt" "$SRC" "$SECTION"

"$MY_DIR"/setup-makefiles.sh
