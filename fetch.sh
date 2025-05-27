fetch() {
    local url="$1"
    local name="$2"

    echo "Fetching file from ${url}..."
    curl -LSs "${url}" > "${name}"

    if [ $? -eq 0 ]; then
        echo "File saved as ${name}"
    else
        echo "Failed to fetch the file from ${url}"
    fi
}

fetch "https://gitlab.com/simonpunk/susfs4ksu/-/raw/gki-android13-5.15/kernel_patches/50_add_susfs_in_gki-android13-5.15.patch?ref_type=heads" "susfs_kernel.patch"
fetch "https://raw.githubusercontent.com/WildKernels/kernel_patches/refs/heads/main/69_hide_stuff.patch" "hide_stuff.patch"
fetch "https://raw.githubusercontent.com/WildKernels/kernel_patches/refs/heads/main/next/syscall_hooks.patch" "syscall_hooks.patch"
