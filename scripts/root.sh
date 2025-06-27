#!/bin/bash

ksu_variant="${1}"
ksu_branch="${2}"

kernel_root="kernel/motorola/sm7550"
kernel_patches="https://raw.githubusercontent.com/SomeEmptyBox/android_build_utils/refs/heads/main/patches/kernel"

susfs_repo="https://gitlab.com/simonpunk/susfs4ksu"
susfs_branch="gki-android13-5.15"

wild_kernel="https://raw.githubusercontent.com/WildKernels/GKI_KernelSU_SUSFS/refs/heads/dev/.github/workflows/build.yml"

# Function for centralized error handling
handle_error() {
    local error_message="$1"
    echo "Error: ${error_message}. Exiting"
    exit 1
}

set -o pipefail
trap 'handle_error "An unexpected error occurred"' ERR

echo
echo "==================== Integrating KernelSU with SUSFS ===================="
echo

echo "Navigating to kernel directory: ${kernel_root}"
cd ${kernel_root}

case "${ksu_branch}" in
    "stable")
        ksu_branch="-"
        ;;
    "dev")
        if [[ "${ksu_variant}" == "ksu" ]]; then
            ksu_branch="-s main"
        elif [[ "${ksu_variant}" == "next" ]]; then
            ksu_branch="-s next"
        fi
        ;;
esac

case "${ksu_variant}" in
    "ksu")
        echo "Adding KernelSU Official..."
        curl -fLSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash ${ksu_branch}
        ;;
    "next")
        echo "Adding KernelSU Next..."
        curl -fLSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash ${ksu_branch}
        ;;
esac

git clone --branch "${susfs_branch}" "${susfs_repo}" susfs
cp ./susfs/kernel_patches/fs/* fs
cp ./susfs/kernel_patches/include/linux/* include/linux

if [[ "${ksu_variant}" == "ksu" ]]; then
    echo "Applying SUSFS patches for Official KernelSU..."
    cd ./KernelSU
    curl -fLSs ${kernel_patches}/susfs_ksu.patch | patch --strip 1 --forward --fuzz 3
    cd ..
elif [[ "${ksu_variant}" == "next" ]]; then
    echo "Applying SUSFS patches for KernelSU Next..."
    cd ./KernelSU-Next
    curl -fLSs ${kernel_patches}/susfs_ksun.patch | patch --strip 1 --forward --fuzz 3
    cd ..
fi

echo "Adding configuration settings to gki_defconfig..."
curl -fLSs "${wild_kernel}" |
    grep 'CONFIG_KSU' |
    if [[ "${ksu_variant}" == "ksu" ]]; then
        grep -v -E 'SUS_SU=n|KPROBES_HOOK=n'
    else
        grep -v 'SUS_SU=y'
    fi |
    awk '{print $2}' |
    sed 's/"//g' >> ./arch/arm64/configs/gki_defconfig

sed -i 's/check_defconfig//' ./build.config.gki

patches=(
    "susfs_kernel"
    "syscall_hooks"
    "hide_stuff"
)

for patch in "${patches[@]}"; do
    patch_url="${kernel_patches}/${patch}.patch"
    echo "Processing patch: ${patch} from ${patch_url}"

    if [[ "${ksu_variant}" == "ksu" && "${patch}" == "syscall_hooks" ]]; then
        echo "Skipping patch: ${patch} because ksu_variant is set to 'ksu'."
        continue
    fi

    echo "Attempting to apply ${patch} patch..."
    curl -fLSs "${patch_url}" | patch --strip 1 --forward --fuzz 3 || handle_error "Failed to apply ${patch} patch"
    echo "${patch} patch applied successfully."
done

echo "changing back to android root..."
cd -

echo
echo "==================== Integration completed successfully ===================="
echo
