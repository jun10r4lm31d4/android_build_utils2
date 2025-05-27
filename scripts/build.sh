#!/bin/bash

# my repo containing patches and scripts
peace_eqe_repo="https://raw.githubusercontent.com/SomeEmptyBox/android_eqe/refs/heads/main"

# Function for centralized error handling
handle_error() {
    local error_message="$1"
    echo "Error: ${error_message}. Exiting."
    exit 1
}

echo
echo "============================"
echo "Sync ROM and device sources."
echo "============================"
echo

# crave resync script
local_script="/opt/crave/resync.sh"
remote_script="${peace_eqe_repo}/scripts/resync.sh"

# Initialize ROM and Device source
rm -rf {device,vendor,kernel,hardware}/motorola vendor/evolution-priv .repo/local_manifests
repo init -u https://github.com/Evolution-X/manifest -b vic --git-lfs || handle_error "Repo init failed"
curl -LSs --create-dirs "${peace_eqe_repo}/manifests/evolution.xml" -o .repo/local_manifests/default.xml || handle_error "Local manifest init failed"
git clone https://${GH_TOKEN}@github.com/SomeEmptyBox/android_vendor_evolution-priv_keys vendor/evolution-priv/keys || handle_error "cloning keys failed"

# check if local sync script exists. if not, use remote sync script
if [ -f "${local_script}" ]; then
    echo "Attempting to run local sync script: ${local_script}"
    "${local_script}" || handle_error "Local sync script execution failed"
else
    echo "Local sync script (${local_script}) not found."
    echo "Attempting to download and run remote sync script from: ${remote_script}"
    (
        set -o pipefail
        curl -fLSs "${remote_script}" | bash
    ) || handle_error "Remote sync script download or execution failed"
fi

echo
echo "===================================="
echo "Sync process completed successfully."
echo "===================================="
echo

# Root using KernelSU or KernelSU Next
# SuSFS patched
# Requires two arguments
# 1. ksu_variant: ksu or next
# 2. ksu_branch: stable or dev
curl -LSs ${peace_eqe_repo}/scripts/root.sh | bash -s next stable

echo
echo "================="
echo "Applying patches."
echo "================="
echo

# Apply patches
patches=(
    "telephony"
    "vibrator"
    "evolution"
)

for patch in "${patches[@]}"; do
    patch_url="${peace_eqe_repo}/patches/${patch}.patch"
    echo "Processing patch: ${patch} from ${patch_url}"

    if ! grep -q "Reversed (or previously applied) patch detected!" <(curl -LSs "${patch_url}" | patch --dry-run --strip 1 --fuzz 3 2>&1); then
        echo "Attempting to apply ${patch} patch..."
        curl -LSs "${patch_url}" | patch --strip 1 --fuzz 3 || handle_error "Failed to apply ${patch} patch"
        echo "${patch} patch applied successfully."
    else
        echo "${patch} patch has already been applied. Skipping."
    fi
    echo
done

echo "Applying miscellaneous fixes..."

cd kernel/motorola/sm7550
sed -i 's/-dirty/-peace/g' ./scripts/setlocalversion
sed -i '2435s/timestamp/*timestamp/g' ./include/uapi/linux/videodev2.h
cd -

echo "All miscellaneous fixes applied successfully."

echo
echo "================================="
echo "All patches applied successfully."
echo "================================="
echo



echo
echo "======================="
echo "Starting build process."
echo "======================="
echo

set -e

echo "Exporting important variables..."
export BUILD_USERNAME="peace"
export BUILD_HOSTNAME="crave"
export KBUILD_BUILD_USER="peace"
export KBUILD_BUILD_HOST="crave"
export TZ="Asia/Kolkata"
export TARGET_HAS_UDFPS=true
export TARGET_INCLUDE_ACCORD=false
export DISABLE_ARTIFACT_PATH_REQUIREMENTS=true

echo "Starting build process..."
source build/envsetup.sh
lunch lineage_eqe-bp1a-user
m installclean
m evolution

echo "Uploading file..."
curl ${peace_eqe_repo}/scripts/upload.sh | bash -s out/target/product/eqe/EvolutionX-*-Unofficial.zip

echo "Cleaning up..."
rm -rf {device,vendor,kernel,hardware}/motorola vendor/evolution-priv .repo/local_manifests
unset GH_TOKEN

echo
echo "============================="
echo "Build completed successfully."
echo "============================="
echo
