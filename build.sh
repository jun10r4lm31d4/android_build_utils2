#!/bin/bash

WILD_KERNEL="https://raw.githubusercontent.com/WildKernels"
EQE="https://raw.githubusercontent.com/SomeEmptyBox/android_eqe/refs/heads/main"

echo " "
echo "===== sync rom ====="

repo init -u https://github.com/Evolution-X/manifest -b vic --git-lfs || { echo "Repo init failed. Exiting."; exit 1; }

# check if local sync script exists if not, run remote sync script
if [ -f "/opt/crave/resync.sh" ]; then
    echo "Running local sync script..."
    /opt/crave/resync.sh || { echo "Sync failed. Exiting."; exit 1; }
else
    echo "Local sync script not found. Running remote sync script..."
    curl "https://raw.githubusercontent.com/accupara/docker-images/refs/heads/master/aosp/common/resync.sh" | bash || { echo "Sync failed. Exiting."; exit 1; }
fi

# apply important patches
if ! grep -q "Reversed (or previously applied) patch detected!" <(curl "${EQE}/telephony.patch" | patch --dry-run --strip 1 2>&1); then
    # Apply the patch
    curl "${EQE}/telephony.patch" | patch --strip 1 || {
        echo "Failed to apply telephony patch. Exiting."
        exit 1
    }
else
    echo "Patch has already been applied. Skipping."
fi

if ! grep -q "Reversed (or previously applied) patch detected!" <(curl "${EQE}/vibrator.patch" | patch --dry-run --strip 1 2>&1); then
    # Apply the patch
    curl "${EQE}/vibrator.patch" | patch --strip 1 || {
        echo "Failed to apply vibrator patch. Exiting."
        exit 1
    }
else
    echo "Patch has already been applied. Skipping."
fi

echo "===== completed ====="
echo " "



# exit on error
set -e

echo " "
echo "===== clone device source ====="

# cleanup old sources
rm -rf {device,vendor,kernel,hardware}/motorola vendor/evolution-priv/keys

git clone --depth 1 --branch lineage-22.2 https://github.com/SomeEmptyBox/android_device_motorola_eqe device/motorola/eqe
git clone --depth 1 --branch lineage-22.2 https://github.com/SomeEmptyBox/android_hardware_motorola hardware/motorola
git clone --depth 1 https://github.com/SomeEmptyBox/android_vendor_evolution-priv_keys vendor/evolution-priv/keys

echo "===== clone vendor source ====="

git clone --depth 1 --branch lineage-22.2 https://gitlab.com/moto-sm7550/proprietary_vendor_motorola_eqe vendor/motorola/eqe
git clone --depth 1 https://gitlab.com/moto-sm7550/proprietary_vendor_motorola_eqe-motcamera vendor/motorola/eqe-motcamera

echo "===== clone kernel source ====="

git clone --depth 1 https://github.com/moto-sm7550-devs/android_kernel_motorola_sm7550 kernel/motorola/sm7550
git clone --depth 1 https://github.com/moto-sm7550-devs/android_kernel_motorola_sm7550-modules kernel/motorola/sm7550-modules
git clone --depth 1 https://github.com/moto-sm7550-devs/android_kernel_motorola_sm7550-devicetrees kernel/motorola/sm7550-devicetrees

echo "===== completed ====="
echo " "




echo " "
echo "===== integrate KernelSU Next with SUSFS and Wild Kernel patches ====="
cd kernel/motorola/sm7550

# KernelSU Next with SUSFS
curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next-susfs/kernel/setup.sh" | bash -s next-susfs

# SUSFS patches for Kernel
git clone -b gki-android13-5.15 https://gitlab.com/simonpunk/susfs4ksu susfs
cp ./susfs/kernel_patches/50_add_susfs_in_gki-android13-5.15.patch .
cp ./susfs/kernel_patches/fs/* fs
cp ./susfs/kernel_patches/include/linux/* include/linux
patch -p1 --fuzz=3 <50_add_susfs_in_gki-android13-5.15.patch

# Wild kernel patches
curl "${WILD_KERNEL}/kernel_patches/refs/heads/main/next/syscall_hooks.patch" | patch -p1 --fuzz=3
curl "${WILD_KERNEL}/kernel_patches/refs/heads/main/69_hide_stuff.patch" | patch -p1 --fuzz=3

# Add configuration settings
curl -s "${WILD_KERNEL}/GKI_KernelSU_SUSFS/refs/heads/dev/.github/workflows/build.yml" | grep '"CONFIG_' | grep -v 'SUS_SU=y' | awk '{print $2}' | sed 's/"//g' >> ./arch/arm64/configs/gki_defconfig

# SUSFS backport patch
curl "${EQE}/susfs_backport.patch" | patch -p1 --fuzz=3

# Some random fixes
sed -i 's/check_defconfig//' ./build.config.gki
sed -i 's/-dirty/-peace/g' ./scripts/setlocalversion
sed -i '2435s/timestamp/*timestamp/g' ./include/uapi/linux/videodev2.h

cd -
echo "===== completed ====="
echo " "




echo " "
echo "===== start build ====="

# export important variables
export BUILD_USERNAME="peace"
export BUILD_HOSTNAME="crave"
export KBUILD_BUILD_USER="peace"
export KBUILD_BUILD_HOST="crave"
export TZ="Asia/Kolkata"
export TARGET_HAS_UDFPS=true
export TARGET_INCLUDE_ACCORD=false
export DISABLE_ARTIFACT_PATH_REQUIREMENTS=true

# start build process
source build/envsetup.sh
lunch lineage_eqe-bp1a-user
make installclean
m evolution

# upload files to Gofile
curl "${EQE}/upload.sh" | bash -s out/target/product/eqe/{*.zip,boot.img,init_boot.img,vendor_boot.img,recovery.img,eqe.json}

echo "===== completed ====="
echo " "
