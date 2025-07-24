#!/bin/bash

set -e

echo "[gitpkg] Installing gitpkg…"

# Root check
if [[ $EUID -ne 0 ]]; then
    echo "[gitpkg] Please run this installer as root (e.g. sudo ./install.sh)"
    exit 1
fi

# Step 1: Install main logic
echo "[gitpkg] Writing /usr/local/bin/gitpkg.sh…"
cat << 'EOF' > /usr/local/bin/gitpkg.sh
#!/bin/bash

resolve_git_url() {
    source="$1"
    repo="$2"

    case "$source" in
        github)
            echo "https://github.com/$repo.git"
            ;;
        gitlab)
            echo "https://gitlab.com/$repo.git"
            ;;
        rawgit)
            echo "$repo"
            ;;
        *)
            echo "[gitpkg] Unknown source: $source"
            return 1
            ;;
    esac
}

install_package() {
    source="$1"
    repo="$2"

    if [[ -z "$source" || -z "$repo" ]]; then
        echo "Usage: gitpkg install <github|gitlab|rawgit> <repo>"
        return 1
    fi

    url=$(resolve_git_url "$source" "$repo") || return 1
    pkgname=$(basename "$repo" .git)
    target_dir="$HOME/.local/gitpkg-packages/$pkgname"

    echo "[gitpkg] Installing $pkgname from $url …"
    mkdir -p "$HOME/.local/gitpkg-packages"

    if [[ -d "$target_dir" ]]; then
        echo "[gitpkg] Package already exists at $target_dir"
        return 0
    fi

    git clone --depth=1 "$url" "$target_dir" || {
        echo "[gitpkg] Failed to clone $url"
        return 1
    }

    cd "$target_dir" || return 1

    if [[ -f install.pkg ]]; then
        echo "[gitpkg] Found install.pkg — running it"
        chmod +x install.pkg
        ./install.pkg
    elif [[ -f appimage.sh ]]; then
        echo "[gitpkg] Found appimage.sh — running it"
        chmod +x appimage.sh
        ./appimage.sh
    elif [[ -f install.sh ]]; then
        echo "[gitpkg] Found install.sh — running it"
        bash install.sh
    elif [[ -f Makefile ]]; then
        echo "[gitpkg] Found Makefile — running make"
        make && sudo make install
    elif [[ -f CMakeLists.txt ]]; then
        echo "[gitpkg] Found CMakeLists.txt — running cmake"
        mkdir -p build && cd build
        cmake .. && make && sudo make install
    elif [[ -f meson.build ]]; then
        echo "[gitpkg] Found meson.build — running meson/ninja"
        meson setup build && ninja -C build && sudo ninja -C build install
    else
        echo "[gitpkg] No supported install method found. Manual setup may be needed."
    fi

    echo "[gitpkg] $pkgname installed."
}

case "$1" in
    install)
        install_package "$2" "$3"
        ;;
    *)
        echo "Usage: gitpkg install <github|gitlab|rawgit> <repo-url-or-path>"
        ;;
esac
EOF

chmod +x /usr/local/bin/gitpkg.sh

# Step 2: Add wrapper to bashrc (only if not already present)
user_home=$(eval echo ~${SUDO_USER:-$USER})
bashrc="$user_home/.bashrc"

if ! grep -q "gitpkg()" "$bashrc"; then
    echo "[gitpkg] Adding wrapper function to $bashrc"
    cat << 'WRAP' >> "$bashrc"

# gitpkg wrapper
gitpkg() {
    bash /usr/local/bin/gitpkg.sh "$@"
}
WRAP
else
    echo "[gitpkg] Wrapper already exists in $bashrc"
fi

echo "[gitpkg] Installation complete!"
echo "Restart your shell or run: source ~/.bashrc"
