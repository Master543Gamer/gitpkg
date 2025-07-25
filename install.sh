#!/bin/bash

set -e

# ----------- Config / Helpers -----------

GITHUB_API="https://api.github.com/repos"
GITLAB_API="https://gitlab.com/api/v4/projects"

ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

normalize_arch() {
  case "$1" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    i386|i686) echo "i386" ;;
    *) echo "$1" ;;
  esac
}

ARCH=$(normalize_arch "$ARCH")

usage() {
  echo "Usage:"
  echo "  $0 github Creator/Repo"
  echo "  $0 gitlab Creator/Repo"
  echo "  $0 rawgit raw_url"
  exit 1
}

install_deb() {
  if command -v apt >/dev/null 2>&1; then
    sudo apt install -y "./$1"
  else
    echo "No apt found, cannot install .deb"
    exit 1
  fi
}

install_rpm() {
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y "./$1"
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y "./$1"
  elif command -v zypper >/dev/null 2>&1; then
    sudo zypper install -y "./$1"
  else
    echo "No supported rpm package manager found"
    exit 1
  fi
}

install_pacman_pkg() {
  if command -v pacman >/dev/null 2>&1; then
    sudo pacman -U --noconfirm "./$1"
  else
    echo "Pacman not found, cannot install Arch package"
    exit 1
  fi
}

install_slackware_pkg() {
  if command -v installpkg >/dev/null 2>&1; then
    sudo installpkg "./$1"
  else
    echo "installpkg not found, cannot install Slackware package"
    exit 1
  fi
}

install_alpine_pkg() {
  if command -v apk >/dev/null 2>&1; then
    sudo apk add "./$1"
  else
    echo "apk not found, cannot install Alpine package"
    exit 1
  fi
}

install_void_pkg() {
  if command -v xbps-install >/dev/null 2>&1; then
    sudo xbps-install -y "./$1"
  else
    echo "xbps-install not found, cannot install Void package"
    exit 1
  fi
}

install_flatpakref() {
  if command -v flatpak >/dev/null 2>&1; then
    flatpak install --user -y "./$1"
  else
    echo "Flatpak not installed"
    exit 1
  fi
}

install_snap() {
  if command -v snap >/dev/null 2>&1; then
    sudo snap install "./$1" --dangerous
  else
    echo "Snap not installed"
    exit 1
  fi
}

run_appimage() {
  chmod +x "./$1"
  "./$1" &
  echo "Running AppImage: $1"
}

install_package() {
  local file=$1
  case "$file" in
    *.deb) install_deb "$file" ;;
    *.rpm) install_rpm "$file" ;;
    *.pkg.tar.zst) install_pacman_pkg "$file" ;;
    *.txz|*.tgz) install_slackware_pkg "$file" ;;
    *.apk) install_alpine_pkg "$file" ;;
    *.xbps) install_void_pkg "$file" ;;
    *.flatpakref) install_flatpakref "$file" ;;
    *.snap) install_snap "$file" ;;
    *.AppImage) run_appimage "$file" ;;
    *) echo "Unknown package type: $file"; return 1 ;;
  esac
}

build_from_source() {
  local repo_url=$1
  local repo_name=$(basename "$repo_url" .git)

  echo "Cloning repository..."
  git clone --depth=1 "$repo_url" || { echo "Git clone failed"; exit 1; }

  cd "$repo_name" || exit 1

  echo "Attempting to auto-detect build system..."

  if [ -f "meson.build" ]; then
    echo "Detected Meson build system."
    if ! command -v meson >/dev/null 2>&1; then
      echo "Meson not installed. Please install meson and ninja."
      exit 1
    fi
    if ! command -v ninja >/dev/null 2>&1; then
      echo "Ninja not installed. Please install ninja."
      exit 1
    fi
    meson setup builddir
    ninja -C builddir
    sudo ninja -C builddir install

  elif [ -f "BUILD.bazel" ] || [ -f "WORKSPACE" ]; then
    echo "Detected Bazel build system."
    if ! command -v bazel >/dev/null 2>&1; then
      echo "Bazel not installed. Please install bazel."
      exit 1
    fi
    bazel build //...
    echo "Bazel build complete. Please check project docs for installation instructions."

  elif [ -f "SConstruct" ]; then
    echo "Detected SCons build system."
    if ! command -v scons >/dev/null 2>&1; then
      echo "SCons not installed. Please install scons."
      exit 1
    fi
    sudo scons install

  elif [ -f "build.gradle" ] || [ -f "gradlew" ]; then
    echo "Detected Gradle build system."
    if [ -f "./gradlew" ]; then
      chmod +x ./gradlew
      ./gradlew build
      ./gradlew install || echo "Install step might need to be manual."
    else
      if ! command -v gradle >/dev/null 2>&1; then
        echo "Gradle not installed. Please install gradle."
        exit 1
      fi
      gradle build
      gradle install || echo "Install step might need to be manual."
    fi

  elif [ -f "pom.xml" ]; then
    echo "Detected Maven build system."
    if ! command -v mvn >/dev/null 2>&1; then
      echo "Maven not installed. Please install maven."
      exit 1
    fi
    mvn package
    mvn install || echo "Install step might need to be manual."

  elif [ -f "go.mod" ]; then
    echo "Detected Go project."
    if ! command -v go >/dev/null 2>&1; then
      echo "Go not installed. Please install Go."
      exit 1
    fi
    go build ./...
    sudo cp "$(basename "$repo_name")" /usr/local/bin/ || echo "Copy binary manually."

  elif [ -f "Cargo.toml" ]; then
    echo "Detected Rust project."
    if ! command -v cargo >/dev/null 2>&1; then
      echo "Cargo not installed. Please install Rust toolchain."
      exit 1
    fi
    cargo build --release
    sudo cp target/release/"$(basename "$repo_name")" /usr/local/bin/ || echo "Copy binary manually."

  elif [ -f "configure" ]; then
    echo "Running ./configure && make && sudo make install"
    ./configure && make && sudo make install

  elif [ -f "CMakeLists.txt" ]; then
    mkdir -p build && cd build
    cmake .. && make && sudo make install

  elif [ -f "Makefile" ]; then
    make && sudo make install

  elif [ -f "setup.py" ]; then
    sudo python3 setup.py install

  else
    echo "No known build system detected. Please build manually."
    exit 1
  fi
}

# ----------- Main Logic -----------

if [ $# -lt 2 ]; then
  usage
fi

source_type=$1
source_val=$2

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cd "$TMPDIR"

case "$source_type" in
  github)
    if [[ ! "$source_val" =~ ^[^/]+/[^/]+$ ]]; then
      echo "Invalid GitHub repo format. Use Creator/Repo"
      exit 1
    fi
    OWNER=${source_val%/*}
    REPO=${source_val#*/}

    echo "Fetching latest release info from GitHub for $OWNER/$REPO..."

    RELEASE_JSON=$(curl -sL "$GITHUB_API/$OWNER/$REPO/releases/latest")
    if echo "$RELEASE_JSON" | grep -q "Not Found"; then
      echo "No releases found, falling back to clone & build."
      build_from_source "https://github.com/$OWNER/$REPO.git"
      exit 0
    fi

    ASSET_URL=""
    ASSET_NAME=""
    for asset_url in $(echo "$RELEASE_JSON" | jq -r '.assets[].browser_download_url'); do
      asset_name=$(basename "$asset_url")
      asset_name_lower=$(echo "$asset_name" | tr '[:upper:]' '[:lower:]')

      if [[ "$asset_name_lower" == *"$ARCH"* ]]; then
        if [[ "$asset_name_lower" =~ \.deb$|\.rpm$|\.appimage$|\.flatpakref$|\.pkg\.tar\.zst$|\.txz$|\.tgz$|\.apk$|\.xbps$|\.snap$ ]]; then
          ASSET_URL="$asset_url"
          ASSET_NAME="$asset_name"
          break
        fi
      fi
    done

    if [ -z "$ASSET_URL" ]; then
      echo "No suitable precompiled package found in releases. Falling back to source build."
      build_from_source "https://github.com/$OWNER/$REPO.git"
      exit 0
    fi

    echo "Downloading asset $ASSET_NAME ..."
    curl -L -o "$ASSET_NAME" "$ASSET_URL"

    echo "Installing $ASSET_NAME ..."
    install_package "$ASSET_NAME"
    ;;

  gitlab)
    ENCODED_PROJECT=$(echo "$source_val" | sed 's/\//%2F/g')

    echo "Fetching latest release info from GitLab for $source_val..."

    RELEASES_JSON=$(curl -sL "$GITLAB_API/$ENCODED_PROJECT/releases")
    if [ -z "$RELEASES_JSON" ] || [ "$RELEASES_JSON" = "[]" ]; then
      echo "No releases found, falling back to clone & build."
      build_from_source "https://gitlab.com/$source_val.git"
      exit 0
    fi

    LATEST_RELEASE=$(echo "$RELEASES_JSON" | jq -r '.[0]')

    ASSET_URL=""
    ASSET_NAME=""
    for asset_url in $(echo "$LATEST_RELEASE" | jq -r '.assets.links[].url'); do
      asset_name=$(basename "$asset_url")
      asset_name_lower=$(echo "$asset_name" | tr '[:upper:]' '[:lower:]')

      if [[ "$asset_name_lower" == *"$ARCH"* ]]; then
        if [[ "$asset_name_lower" =~ \.deb$|\.rpm$|\.appimage$|\.flatpakref$|\.pkg\.tar\.zst$|\.txz$|\.tgz$|\.apk$|\.xbps$|\.snap$ ]]; then
          ASSET_URL="$asset_url"
          ASSET_NAME="$asset_name"
          break
        fi
      fi
    done

    if [ -z "$ASSET_URL" ]; then
      echo "No suitable precompiled package found in releases. Falling back to source build."
      build_from_source "https://gitlab.com/$source_val.git"
      exit 0
    fi

    echo "Downloading asset $ASSET_NAME ..."
    curl -L -o "$ASSET_NAME" "$ASSET_URL"

    echo "Installing $ASSET_NAME ..."
    install_package "$ASSET_NAME"
    ;;

  rawgit)
    echo "Downloading from raw URL: $source_val"

    FILE_NAME=$(basename "$source_val")
    curl -L -o "$FILE_NAME" "$source_val"

    case "$FILE_NAME" in
      *.deb|*.rpm|*.flatpakref|*.AppImage|*.pkg.tar.zst|*.txz|*.tgz|*.apk|*.xbps|*.snap)
        echo "Installing $FILE_NAME ..."
        install_package "$FILE_NAME"
        ;;
      *.zip)
        echo "Unzipping $FILE_NAME ..."
        unzip "$FILE_NAME"
        ;;
      *.tar.gz|*.tgz)
        echo "Extracting $FILE_NAME ..."
        tar xzf "$FILE_NAME"
        ;;
      *)
        echo "Unknown file type. Please handle manually."
        ;;
    esac
    ;;

  *)
    usage
    ;;
esac

echo "Installation process complete."
exit 0
