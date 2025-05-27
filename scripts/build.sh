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
remote_script="https://raw.githubusercontent.com/accupara/docker-images/refs/heads/master/aosp/common/resync.sh"

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

# wild kernel repo
wild_kernel="https://raw.githubusercontent.com/WildKernels/GKI_KernelSU_SUSFS/refs/heads/dev"

echo "Navigating to kernel directory: ${kernel_root}"
cd ${kernel_root}

echo "Setting up KernelSU Next..."
curl -LSs "${ksunext_script}" | bash -s ${ksunext_branch}

git clone --branch "${susfs_branch}" "${susfs_repo}" susfs \
    || handle_error "Failed to clone SUSFS repository"
echo "SUSFS repository cloned successfully."

cp ./susfs/kernel_patches/fs/* fs \
    || handle_error "Failed to copy SUSFS filesystem patches"
echo "SUSFS filesystem patches copied successfully."

cp ./susfs/kernel_patches/include/linux/* include/linux \
    || handle_error "Failed to copy SUSFS include files"
echo "SUSFS include files copied successfully."

echo "Adding configuration settings to gki_defconfig..."
curl -LSs "${wild_kernel}/.github/workflows/build.yml" | \
    grep '"CONFIG_' | \
    grep -v 'SUS_SU=y' | \
    awk '{print $2}' | \
    sed 's/"//g' >> ./arch/arm64/configs/gki_defconfig

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
echo "================="
echo "Applying patches."
echo "================="
echo

# Apply patches
patches=(
    "telephony"
    "vibrator"
    "evolution"
    "susfs_kernel"
    "syscall_hooks"
    "hide_stuff"
    "susfs_backport"
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

echo
echo "============================="
echo "Build completed successfully."
echo "============================="
echo
