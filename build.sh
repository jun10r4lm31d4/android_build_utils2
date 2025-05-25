#!/bin/bash

# my repo containing patches and scripts
peace_eqe_repo="https://raw.githubusercontent.com/SomeEmptyBox/android_eqe/refs/heads/main"

# crave resync script
local_script_path="/opt/crave/resync.sh"
remote_script_url="https://raw.githubusercontent.com/accupara/docker-images/refs/heads/master/aosp/common/resync.sh"

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

rm -rf {device,vendor,kernel,hardware}/motorola vendor/evolution-priv/keys .repo/local_manifests/*
repo init -u https://github.com/Evolution-X/manifest -b vic --git-lfs || handle_error "Repo init failed"
curl -LSs "${peace_eqe_repo}/default.xml" > .repo/local_manifests/default.xml

# check if local sync script exists. if not, use remote sync script
if [ -f "${local_script_path}" ]; then
    echo "Attempting to run local sync script: ${local_script_path}"
    "${local_script_path}" || handle_error "Local sync script execution failed"
else
    echo "Local sync script (${local_script_path}) not found."
    echo "Attempting to download and run remote sync script from: ${remote_script_url}"
    (
        set -o pipefail
        curl -fLSs "${remote_script_url}" | bash
    ) || handle_error "Remote sync script download or execution failed"
fi

echo
echo "===================================="
echo "Sync process completed successfully."
echo "===================================="
echo

sed -i 's/powershare@1.0/powershare/g' device/motorola/eqe/device.mk
echo '$(call inherit-product, vendor/motorola/eqe-motcamera/eqe-motcamera-vendor.mk)' >> device/motorola/eqe/device.mk
echo 'include vendor/motorola/eqe-motcamera/BoardConfigVendor.mk' >> device/motorola/eqe/BoardConfig.mk

echo
echo "================="
echo "Applying patches."
echo "================="
echo

# Apply patches
patches=(
    "telephony"
    "vibrator"
    "ota_support"
    "evo_overlay"
)

for patch in "${patches[@]}"; do
    patch_url="${peace_eqe_repo}/${patch}.patch"
    echo "Processing patch: ${patch} from ${patch_url}"

    if ! grep -q "Reversed (or previously applied) patch detected!" <(curl -LSs "${patch_url}" | patch --dry-run --strip 1 2>&1); then
        echo "Attempting to apply ${patch} patch..."
        curl -LSs "${patch_url}" | patch --strip 1 || handle_error "Failed to apply ${patch} patch"
        echo "${patch} patch applied successfully."
    else
        echo "${patch} patch has already been applied. Skipping."
    fi
    echo
done

echo
echo "================================="
echo "All patches applied successfully."
echo "================================="
echo



echo
echo "============================================================="
echo "Integrating KernelSU Next with SUSFS and Wild Kernel patches."
echo "============================================================="
echo

kernel_root="kernel/motorola/sm7550"

ksunext_script="https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next-susfs/kernel/setup.sh"
ksunext_branch="next-susfs"

susfs_repo="https://gitlab.com/simonpunk/susfs4ksu"
susfs_branch="gki-android13-5.15"
patch_file="50_add_susfs_in_gki-android13-5.15.patch"
temp_susfs_dir="susfs"

# wild kernel repo
wild_kernel_gki="https://raw.githubusercontent.com/WildKernels/GKI_KernelSU_SUSFS/refs/heads/dev"
wild_kernel_patches="https://raw.githubusercontent.com/WildKernels/kernel_patches/refs/heads/main"

echo "Navigating to kernel directory: ${kernel_root}"
cd ${kernel_root}

echo "Setting up KernelSU Next..."
curl -LSs "${ksunext_script}" | bash -s ${ksunext_branch}

git clone --branch "${susfs_branch}" "${susfs_repo}" ${temp_susfs_dir} \
    || handle_error "Failed to clone SUSFS repository"
echo "SUSFS repository cloned successfully."

cp ./${temp_susfs_dir}/kernel_patches/${patch_file} . \
    || handle_error "Failed to copy SUSFS patch"
echo "SUSFS patch copied successfully."

cp ./${temp_susfs_dir}/kernel_patches/fs/* fs \
    || handle_error "Failed to copy SUSFS filesystem patches"
echo "SUSFS filesystem patches copied successfully."

cp ./${temp_susfs_dir}/kernel_patches/include/linux/* include/linux \
    || handle_error "Failed to copy SUSFS include files"
echo "SUSFS include files copied successfully."

if ! grep -q "Reversed (or previously applied) patch detected!" <(patch --dry-run --strip 1 < ${patch_file}); then
    echo "Attempting to apply ${patch_file} patch..."
    patch --strip 1 < ${patch_file} || handle_error "Failed to apply ${patch_file} patch"
    echo "${patch_file} patch applied successfully."
else
    echo "${patch_file} patch has already been applied. Skipping."
fi

echo "Cleaning up temporary SUSFS repository '${temp_susfs_dir}'..."
rm -rf "${temp_susfs_dir}" \
    || echo "WARNING: Failed to clean up temporary '${temp_susfs_dir}' directory." >&2
echo "Cleanup complete."

if ! grep -q "Reversed (or previously applied) patch detected!" <(curl -LSs "${wild_kernel_patches}/next/syscall_hooks.patch" | patch --dry-run --strip 1 --fuzz=3 2>&1); then
    echo "Attempting to apply syscall_hooks patch..."
    curl -LSs "${wild_kernel_patches}/next/syscall_hooks.patch" | patch --strip 1 --fuzz=3 || handle_error "Failed to apply syscall_hooks patch"
    echo "syscall_hooks patch applied successfully."
else
    echo "syscall_hooks patch has already been applied. Skipping."
fi

if ! grep -q "Reversed (or previously applied) patch detected!" <(curl -LSs "${wild_kernel_patches}/69_hide_stuff.patch" | patch --dry-run --strip 1 --fuzz=3 2>&1); then
    echo "Attempting to apply hide_stuff patch..."
    curl -LSs "${wild_kernel_patches}/69_hide_stuff.patch" | patch --strip 1 --fuzz=3 || handle_error "Failed to apply hide_stuff patch"
    echo "hide_stuff patch applied successfully."
else
    echo "hide_stuff patch has already been applied. Skipping."
fi

echo "Adding configuration settings to gki_defconfig..."
curl -LSs "${wild_kernel_gki}/.github/workflows/build.yml" | \
    grep '"CONFIG_' | \
    grep -v 'SUS_SU=y' | \
    awk '{print $2}' | \
    sed 's/"//g' >> ./arch/arm64/configs/gki_defconfig

if ! grep -q "Reversed (or previously applied) patch detected!" <(curl -LSs "${peace_eqe_repo}/susfs_backport.patch" | patch --dry-run --strip 1 2>&1); then
    echo "Attempting to apply susfs_backport patch..."
    curl -LSs "${peace_eqe_repo}/susfs_backport.patch" | patch --strip 1 || handle_error "Failed to apply susfs_backport patch"
    echo "susfs_backport patch applied successfully."
else
    echo "susfs_backport patch has already been applied. Skipping."
fi

echo "Applying miscellaneous fixes..."

echo "  - Removing 'check_defconfig' from build.config.gki..."
if [ ! -f "./build.config.gki" ]; then
    echo "File not found: build.config.gki."
fi
sed -i 's/check_defconfig//' ./build.config.gki \
    || echo "Failed to apply 'check_defconfig' fix to ./build.config.gki."
echo "    Fix applied for ./build.config.gki."

echo "  - Changing '-dirty' to '-peace' in ./scripts/setlocalversion..."
if [ ! -f "./scripts/setlocalversion" ]; then
    echo "File not found: ./scripts/setlocalversion."
fi
sed -i 's/-dirty/-peace/g' ./scripts/setlocalversion \
    || echo "Failed to apply version fix to ./scripts/setlocalversion."
echo "    Fix applied for ./scripts/setlocalversion."

echo "  - Modifying timestamp definition in ./include/uapi/linux/videodev2.h..."
if [ ! -f "./include/uapi/linux/videodev2.h" ]; then
    echo "File not found: ./include/uapi/linux/videodev2.h."
fi
sed -i '2435s/timestamp/*timestamp/g' ./include/uapi/linux/videodev2.h \
    || echo "Failed to apply timestamp fix to ./include/uapi/linux/videodev2.h."
echo "    Fix applied for ./include/uapi/linux/videodev2.h."

echo "All miscellaneous fixes applied successfully."

echo "changing back to android root..."
cd -

echo
echo "==================================="
echo "Integration completed successfully."
echo "==================================="
echo



echo
echo "======================="
echo "Starting build process."
echo "======================="
echo

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
make installclean
m evolution

echo "Uploading files to Gofile..."
curl -LSs "${peace_eqe_repo}/upload.sh" | bash -s out/target/product/eqe/{*.zip,boot.img,init_boot.img,vendor_boot.img,recovery.img,eqe.json}

echo
echo "============================="
echo "Build completed successfully."
echo "============================="
echo
