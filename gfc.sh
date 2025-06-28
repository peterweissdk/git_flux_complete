#!/bin/bash
# ----------------------------------------------------------------------------
# Script Name: gfc.sh
# Description: Tool designed to help you commit and push changes to git and reconcile flux
# Author: peterweissdk
# Email: peterweissdk@flems.dk
# Date: 2025-06-28
# Version: v1.0.0
# Usage: Run gfc.sh, follow instructions or -h for help
# ----------------------------------------------------------------------------

# Installs script
install() {
    read -p "Do you want to install this script? (yes/no): " answer
    case $answer in
        [Yy]* )
            # Set default installation path
            default_path="/usr/local/bin"
            
            # Prompt for installation path
            read -p "Enter the installation path [$default_path]: " install_path
            install_path=${install_path:-$default_path}  # Use default if no input

            # Get the filename of the script
            script_name=$(basename "$0")

            # Copy the script to the specified path
            echo "Copying $script_name to $install_path..."
            
            # Check if the user has write permissions
            if [ ! -w "$install_path" ]; then
                echo "You need root privileges to install the script in $install_path."
                if sudo cp "$0" "$install_path/$script_name"; then
                    sudo chmod +x "$install_path/$script_name"
                    echo "Script installed successfully."
                else
                    echo "Failed to install script."
                    exit 1
                fi
            else
                if cp "$0" "$install_path/$script_name"; then
                    chmod +x "$install_path/$script_name"
                    echo "Script installed successfully."
                else
                    echo "Failed to install script."
                    exit 1
                fi
            fi
            ;;
        [Nn]* )
            echo "Exiting script."
            exit 0
            ;;
        * )
            echo "Please answer yes or no."
            install
            ;;
    esac

    exit 0
}

# Updates version of script
update_version() {
    # Extract the current version from the script header
    version_line=$(grep "^# Version:" "$0")
    current_version=${version_line#*: }  # Remove everything up to and including ": "
    
    echo "Current version: $current_version"
    
    # Prompt the user for a new version
    read -p "Enter new version (current: $current_version): " new_version
    
    # Update the version in the script
    sed -i "s/^# Version: .*/# Version: $new_version/" "$0"
    
    echo "Version updated to: $new_version"

    exit 0
}

# Prints out version
version() {
    # Extract the current version from the script header
    version_line=$(grep "^# Version:" "$0")
    current_version=${version_line#*: }  # Remove everything up to and including ": "
    
    echo "Script version: $current_version"

    exit 0
}

# Prints out help
help() {
    echo "Run script to commit and push changes to git and reconcile flux."
    echo "Usage: $0 [-i | --install] [-u | --update-version] [-v | --version] [-h | --help]"

    exit 0
}

# Check for flags
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -i|--install) install; shift ;;
        -u|--update-version) update_version; shift ;;
        -v|--version) version; shift ;;
        -h|--help) help; shift ;;
        *) echo "Unknown option: $1"; help; exit 1 ;;
    esac
done

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "Error: git is not installed"
    exit 1
fi
echo "Git is available"

# Check if flux is installed
if ! command -v flux &> /dev/null; then
    echo "Error: flux is not installed"
    exit 1
fi
echo "Flux is available"

# Check if current directory is a git repository
if ! git rev-parse --is-inside-work-tree &> /dev/null; then
    echo "Error: Current directory is not a git repository"
    exit 1
fi
echo "Current directory is a git repository"

# Check if branch is up to date with origin/main
git fetch origin main &> /dev/null
local_commit=$(git rev-parse HEAD)
remote_commit=$(git rev-parse origin/main)

if [ "$local_commit" = "$remote_commit" ]; then
    echo "Your branch is up to date with 'origin/main'."
    exit 0
fi

# Add all changes
if ! git add .; then
    echo "Error: Failed to add changes"
    exit 1
fi
echo "git add successful"

# Display commit type options
echo "Choose commit type (1-11):"
echo "1:  feat – a new feature is introduced with the changes"
echo "2:  fix – a bug fix has occurred"
echo "3:  chore – changes that do not relate to a fix or feature and don't modify src or test files"
echo "4:  refactor – refactored code that neither fixes a bug nor adds a feature"
echo "5:  docs – updates to documentation such as a the README or other markdown files"
echo "6:  style – changes that do not affect the meaning of the code"
echo "7:  test – including new or correcting previous tests"
echo "8:  perf – performance improvements"
echo "9:  ci – continuous integration related"
echo "10: build – changes that affect the build system or external dependencies"
echo "11: revert – reverts a previous commit"

# Read user choice
read -p "Enter number (1-11): " choice

# Map choice to prefix
case $choice in
    1) PREFIX_COMMIT_MESSAGE="feat";;
    2) PREFIX_COMMIT_MESSAGE="fix";;
    3) PREFIX_COMMIT_MESSAGE="chore";;
    4) PREFIX_COMMIT_MESSAGE="refactor";;
    5) PREFIX_COMMIT_MESSAGE="docs";;
    6) PREFIX_COMMIT_MESSAGE="style";;
    7) PREFIX_COMMIT_MESSAGE="test";;
    8) PREFIX_COMMIT_MESSAGE="perf";;
    9) PREFIX_COMMIT_MESSAGE="ci";;
    10) PREFIX_COMMIT_MESSAGE="build";;
    11) PREFIX_COMMIT_MESSAGE="revert";;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

# Get commit message from user
read -p "Enter commit message: " COMMIT_MESSAGE

# Commit changes
if ! git commit -m "$PREFIX_COMMIT_MESSAGE: $COMMIT_MESSAGE"; then
    echo "Error: Failed to commit changes"
    exit 1
fi
echo "git commit successful"

# Push to main branch
if ! git push origin main; then
    echo "Error: Failed to push changes"
    exit 1
fi
echo "git push successful"

# Reconcile flux
if ! flux reconcile source git flux-system; then
    echo "Error: Failed to reconcile flux"
    exit 1
fi
echo "flux reconcile successful"

exit 0
