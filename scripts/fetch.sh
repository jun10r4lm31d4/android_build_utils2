fetch() {
    local name="$1"
    local url="$2"

    echo "Fetching ${name} from ${url}..."
    curl -fLSs "${url}" -o "../${name}"

    if [ $? -eq 0 ]; then
        echo "File saved as ${name}"
    else
        echo "Failed to fetch the file from ${url}"
    fi
}

fetch "patches/susfs_ksu.patch"         "https://gitlab.com/simonpunk/susfs4ksu/-/raw/gki-android13-5.15/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch?ref_type=heads"
fetch "patches/susfs_kernel.patch"      "https://gitlab.com/simonpunk/susfs4ksu/-/raw/gki-android13-5.15/kernel_patches/50_add_susfs_in_gki-android13-5.15.patch?ref_type=heads"
fetch "patches/hide_stuff.patch"        "https://raw.githubusercontent.com/WildKernels/kernel_patches/refs/heads/main/69_hide_stuff.patch"
fetch "patches/syscall_hooks.patch"     "https://raw.githubusercontent.com/WildKernels/kernel_patches/refs/heads/main/next/syscall_hooks.patch"
fetch "patches/vibrator.patch"          "https://github.com/moto-sm7550-devs/android_vendor_qcom_opensource_vibrator/commit/3a403297c8713c783eeac02d0d6bfb936854a978.patch"
fetch "patches/telephony.patch"         "https://github.com/2by2-Project/packages_services_Telephony/commit/6d1276ad67ec5a023e4d65cec1e0c659cf756cef.patch"

fetch "scripts/resync.sh"               "https://raw.githubusercontent.com/accupara/docker-images/refs/heads/master/aosp/common/resync.sh"
fetch "scripts/upload.sh"               "https://raw.githubusercontent.com/Drenzzz/script-upload/refs/heads/master/upload.sh"

replace_paths() {
    local patch_file="$1"
    local pattern="$2"
    local replacement="$3"

    sed -i \
        -e "s|a/${pattern}|a/${replacement}|g" \
        -e "s|b/${pattern}|b/${replacement}|g" \
        "$patch_file"
}

replace_paths "../patches/vibrator.patch"   "aidl"  "vendor/qcom/opensource/vibrator/aidl"
replace_paths "../patches/telephony.patch"  "src"   "packages/services/Telephony/src"
