fetch() {
    local name="$1"
    local url="$2"

    echo "Fetching ${name} from ${url}..."
    curl -LSs "${url}" -o "../patches/${name}.patch"

    if [ $? -eq 0 ]; then
        echo "File saved as ${name}"
    else
        echo "Failed to fetch the file from ${url}"
    fi
}

fetch "susfs_kernel"    "https://gitlab.com/simonpunk/susfs4ksu/-/raw/gki-android13-5.15/kernel_patches/50_add_susfs_in_gki-android13-5.15.patch?ref_type=heads"
fetch "hide_stuff"      "https://raw.githubusercontent.com/WildKernels/kernel_patches/refs/heads/main/69_hide_stuff.patch"
fetch "syscall_hooks"   "https://raw.githubusercontent.com/WildKernels/kernel_patches/refs/heads/main/next/syscall_hooks.patch"
fetch "vibrator"        "https://github.com/moto-sm7550-devs/android_vendor_qcom_opensource_vibrator/commit/3a403297c8713c783eeac02d0d6bfb936854a978.patch"
fetch "telephony"       "https://github.com/2by2-Project/packages_services_Telephony/commit/6d1276ad67ec5a023e4d65cec1e0c659cf756cef.patch"
