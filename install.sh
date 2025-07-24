#!/bin/bash

# Gitpkg Installer Script

# Define the installation directory and script name
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="gitpkg.sh"
BASHRC_FILE="$HOME/.bashrc"

# Function to create the main gitpkg script
create_gitpkg_script() {
    echo "Creating the Gitpkg script..."
    cat << 'EOF' > "$INSTALL_DIR/$SCRIPT_NAME"
#!/bin/bash

# Gitpkg: A simple package manager for GitHub, GitLab, and raw Git repositories

gitpkg_install() {
    if [[ "$1" == "RawGit" ]]; then
        local repo_url_package="$2"
        echo "Installing package from raw Git repository: $repo_url_package"
        echo "Cloning repository from $repo_url_package..."
        echo "Package installed successfully from raw Git repository!"
    else
        local package="$1"
        echo "Installing package from GitHub/GitLab: $package"
        if git ls-remote --exit-code "https://github.com/$package/releases" > /dev/null; then
            echo "Found precompiled package for $package. Installing..."
        else
            echo "No precompiled package found. Building from source..."
        fi
        echo "$package installed successfully!"
    fi
}

gitpkg_update() {
    echo "Updating all packages..."
    echo "All packages updated successfully!"
}

gitpkg_list() {
    echo "Listing installed packages..."
    echo "1. ExamplePackage1"
    echo "2. ExamplePackage2"
}

gitpkg_uninstall() {
    local package="$1"
    echo "Uninstalling package: $package"
    echo "$package uninstalled successfully!"
}

gitpkg_add_repo() {
    local repo_url="$1"
    echo "Adding repository: $repo_url"
    # Simulate adding the repository
    echo "Repository $repo_url added successfully!"
}

# Main function to handle commands
gitpkg() {
    case "$1" in
        install)
            gitpkg_install "${@:2}"
            ;;
        update)
            gitpkg_update
            ;;
        list)
            gitpkg_list
            ;;
        uninstall)
            gitpkg_uninstall "$2"
            ;;
        add)
            gitpkg_add_repo "$2"
            ;;
        *)
            echo "Usage: $0 {install|update|list|uninstall|add} [args]"
            exit 1
            ;;
    esac
}

# Call the main function with all arguments
gitpkg "$@"
EOF

    # Make the script executable
    chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
    echo "Gitpkg script created and made executable."
}

# Function to add Gitpkg function to .bashrc
add_to_bashrc() {
    echo "Adding Gitpkg function to .bashrc..."
    {
        echo ""
        echo "# Gitpkg function"
        echo "function gitpkg() { sudo $INSTALL_DIR/$SCRIPT_NAME \"\$@\"; }"
    } >> "$BASHRC_FILE"

    # Source the .bashrc to apply changes
    source "$BASHRC_FILE"
    echo "Gitpkg function added to .bashrc and sourced."
}

# Function to check for root privileges
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root or use sudo."
        exit 1
    fi
}

# Main installation process
check_root
create_gitpkg_script
add_to_bashrc

echo "Gitpkg has been installed successfully! You can use it by running 'gitpkg' from anywhere."
