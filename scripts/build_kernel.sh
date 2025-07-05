#!/bin/bash

# my repo containing patches and scripts
build_utils="https://raw.githubusercontent.com/SomeEmptyBox/android_build_utils/refs/heads/main"

repo init -u https://android.googlesource.com/kernel/manifest -b common-android13-5.15
curl -fLSs --create-dirs "${build_utils}/manifests/kernel.xml" -o .repo/local_manifests/default.xml

# crave resync script
local_script="/opt/crave/resync.sh"
remote_script="${build_utils}/scripts/resync.sh"

# check if local sync script exists. if not, use remote sync script
if [ -f "${local_script}" ]; then
    echo "Attempting to run local sync script: ${local_script}"
    "${local_script}" || handle_error "Local sync script execution failed"
else
    echo "Local sync script (${local_script}) not found."
    echo "Attempting to download and run remote sync script from: ${remote_script}"
    curl -fLSs "${remote_script}" | bash || handle_error "Remote sync script download or execution failed"
fi

ksu_variant="${1}"
ksu_branch="stable"

if [ "$#" -ge 2 ]; then
    ksu_branch="${2}"
fi

if [ "$#" -ge 1 ]; then
    cd sm7550
    curl -fLSs https://raw.githubusercontent.com/SomeEmptyBox/android_build_utils/refs/heads/main/scripts/root.sh | bash -s ${ksu_variant} ${ksu_branch}
    cd -
fi

LTO=thin BUILD_CONFIG=sm7550/build.config.gki.aarch64 build/build.sh || exit 1

mkdir bootimgs && cd bootimgs
curl -fLSs "$STOCK_ROM" -o "$(mktemp /tmp/zip_XXXXXX.zip)"
unzip -o "$(ls -t /tmp/zip_*.zip | head -1)" "boot.img" -d stock_boot.img
rm "$(ls -t /tmp/zip_*.zip | head -1)"
curl -LO https://raw.githubusercontent.com/TheWildJames/Android_Kernel_Tutorials/gki-2.0/tools/magiskboot
chmod +x magiskboot
magiskboot unpack stock_boot.img
cp ../out/*/dist/Image kernel
magiskboot repack stock_boot.img boot.img
