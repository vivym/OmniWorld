#!/usr/bin/env bash
# Description: Setup workspace for the project

# Exits if error occurs
set -e

# Set tab-width to 4 in this script
tabs 4

#==
# Helper functions
#==

# Print the usage of the script
print_usage() {
    echo -e "\nUsage: $(basename $0) [conda_env_name] -- Script to setup the workspace for OmniWorld"
    echo -e "\nOptional arguments:"
    echo -e "\t-h, --help               Show this help message and exit."
    echo -e "\t-c, --conda [NAME]       Name of the conda environment to create. Default: 'omni-world'."
    echo -e "\t--isaac-sim [PATH]       Path to the Isaac Sim installation directory. If not provided, the script will search for the latest installation in the default location."
    echo -e "\t--isaac-lab-repo [URL]   URL of the Isaac Lab repository. If not provided, the script will use the official github repository."
    echo -e "\n" >&2
}

# Find the latest Isaac Sim installation
find_latest_isaac_sim() {
    local ov_pkg_dir="$HOME/.local/share/ov/pkg"
    # Check if the directory exists
    if [ ! -d "$ov_pkg_dir" ]; then
        echo "[Error] Isaac Sim installation directory not found: $ov_pkg_dir"
        exit 1
    fi

    # Find the latest Isaac Sim installation: `isaac-sim-*.*.*`
    local latest_isaac_sim=$(ls -1 $ov_pkg_dir | grep -E '^isaac-sim-[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1)
    if [ -z "$latest_isaac_sim" ]; then
        echo "[Error] No Isaac Sim installation found in the directory: $ov_pkg_dir"
        exit 1
    fi

    # Return the path to the latest Isaac Sim installation
    echo "$ov_pkg_dir/$latest_isaac_sim"
}

#==
# Main
#==

# Check if conda is installed
if ! command -v conda &> /dev/null; then
    echo "[Error] Conda is not installed. Please install conda before running this script."
    exit 1
fi

# Set the path of the workspace directory
export WS_DIR=$(realpath $(dirname $0)/..)
cd $WS_DIR

conda_env_name="omni-world"
isaac_sim_path=""
isaac_lab_repo="https://github.com/isaac-sim/IsaacLab.git"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            print_usage
            exit 0
            ;;
        -c|--conda)
            shift
            if [ -z "$1" ]; then
                echo "[Error] No conda environment name provided."
                print_usage
                exit 1
            fi
            conda_env_name=$1
            ;;
        --isaac-sim)
            shift
            if [ -z "$1" ]; then
                echo "[Error] No path to Isaac Sim installation provided."
                print_usage
                exit 1
            fi
            isaac_sim_path=$1
            shift
            ;;
        --isaac-lab-repo)
            shift
            if [ -z "$1" ]; then
                echo "[Error] No URL of the Isaac Lab repository provided."
                print_usage
                exit 1
            fi
            isaac_lab_repo=$1
            ;;
        *)
            echo "[Error] Invalid argument provided: $1"
            print_help
            exit 1
            ;;
    esac
    shift
done

# Find the latest Isaac Sim installation if path is not provided
if [ -z "$isaac_sim_path" ]; then
    isaac_sim_path=$(find_latest_isaac_sim)
fi

echo "[INFO] Setting up workspace for OmniWorld"
echo "[INFO] Workspace directory: $WS_DIR"
echo "[INFO] Conda environment name: $conda_env_name"
echo "[INFO] Isaac Sim path: $isaac_sim_path"
echo "[INFO] Isaac Lab repository: $isaac_lab_repo"

# If `_isaac_lab` is already exists, ask the user to delete it or not
if [ -d "$WS_DIR/_isaac_lab" ]; then
    read -p "[Warning] Isaac Lab repository already exists. Do you want to delete it? (y/n): " delete_isaac_lab
    if [ "$delete_isaac_lab" == "y" ]; then
        echo "[INFO] Deleting the existing Isaac Lab repository"
        rm -rf $WS_DIR/_isaac_lab
    else
        echo "Exiting..."
        exit 0
    fi
fi

echo "[INFO] Cloning IsaacLab repository from: $isaac_lab_repo"
git clone $isaac_lab_repo $WS_DIR/_isaac_lab

# Install IsaacLab following: https://isaac-sim.github.io/IsaacLab/source/setup/installation/binaries_installation.html
echo "[INFO] Installing Isaac Lab"

cd $WS_DIR/_isaac_lab

# Create a symbolic link to the Isaac Sim installation
ln -s $isaac_sim_path _isaac_sim

# Setup the conda environment
echo "[INFO] Creating conda environment: $conda_env_name"
./isaaclab.sh --conda $conda_env_name

# Activate the conda environment
eval "$(conda shell.bash hook)"
conda activate $conda_env_name

pip install --upgrade pip

# Install the dependencies
echo "[INFO] Installing dependencies"
./isaaclab.sh --install

# Return to the workspace directory
cd $WS_DIR

# Check if the installation was successful by running `python scripts/check_installation.py`
echo "[INFO] Checking the installation"

if ! python scripts/check_installation.py; then
    echo "[Error] Installation failed. Please check the logs above."
    exit 1
fi

# Install dependencies for OmniWorld
echo "[INFO] Installing OmniWorld dependencies"
pip install -v -e .

# Setup the vscode settings
echo "[INFO] Setting up vscode settings"
python .vscode/tools/setup_vscode.py --python "$(command -v python)"

echo "[INFO] Workspace setup completed successfully"
echo "[INFO] To activate the conda environment, run: conda activate $conda_env_name"
echo "[INFO] To deactivate the conda environment, run: conda deactivate"
