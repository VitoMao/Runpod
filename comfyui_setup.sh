#this script corresponds to this tutorial video: https://www.youtube.com/watch?v=5hCGDcfPy8Y
#You only need to run this script once. However, when you start a new runpod server, you will  need to  initialize conda in the shell. 
#1. run the following command to intialize conda in the shell
#/workspace/miniconda3/bin/conda init bash
#2. run the following command to activate the conda environment
#conda activate comfyui
#3. run the following command to start comfyui
#python main.py --listen

#!/bin/bash
# ComfyUI single environment setup with Python 3.12

echo "
========================================
🚀 Starting ComfyUI setup...
========================================
"

# Create base directories
echo "
----------------------------------------
📁 Creating base directories...
----------------------------------------"
mkdir -p /workspace/ComfyUI
mkdir -p /workspace/miniconda3

# Download and install Miniconda with Python 3.12 support
echo "
----------------------------------------
📥 Downloading and installing Miniconda...
----------------------------------------"
if [ ! -f "/workspace/miniconda3/bin/conda" ]; then
    cd /workspace/miniconda3
    wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
    chmod +x Miniconda3-latest-Linux-x86_64.sh
    ./Miniconda3-latest-Linux-x86_64.sh -b -p /workspace/miniconda3 -f
    rm Miniconda3-latest-Linux-x86_64.sh
else
    echo "✅ Miniconda already installed, skipping..."
fi

# Initialize conda in the shell
echo "
----------------------------------------
🐍 Initializing conda...
----------------------------------------"
source /workspace/miniconda3/bin/activate
conda init bash > /dev/null 2>&1
eval "$(/workspace/miniconda3/bin/conda shell.bash hook)"

# Update conda to latest version
echo "Updating conda to latest version..."
conda update -n base -c defaults conda -y

# Clone ComfyUI
echo "
----------------------------------------
📥 Cloning ComfyUI repository...
----------------------------------------"
if [ ! -d "/workspace/ComfyUI/.git" ]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI
else
    echo "✅ ComfyUI repository already exists, skipping clone..."
fi

# Clone ComfyUI-Manager
echo "
----------------------------------------
📥 Installing ComfyUI-Manager...
----------------------------------------"
MANAGER_DIR="/workspace/ComfyUI/custom_nodes/ComfyUI-Manager"
if [ ! -d "$MANAGER_DIR/.git" ]; then
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git "$MANAGER_DIR"
else
    echo "✅ ComfyUI-Manager already installed, skipping clone..."
fi

echo "
----------------------------------------
🌟 Creating conda environment with Python 3.12...
----------------------------------------"
ENV_NAME="comfyui"
ENV_PATH="/workspace/miniconda3/envs/$ENV_NAME"

# Accept Conda's terms of service for the main and R channels
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

# Function to create environment
create_environment() {
    # Remove invalid environment if exists
    if [ -d "$ENV_PATH" ] && [ ! -f "$ENV_PATH/bin/python" ]; then
        echo "⚠️ Removing invalid environment directory: $ENV_PATH"
        rm -rf "$ENV_PATH"
    fi
    
    echo "🔄 Creating new conda environment '$ENV_NAME' with Python 3.12"
    conda create --name "$ENV_NAME" python=3.12 -y
    
    # Validate environment creation
    if [ ! -f "$ENV_PATH/bin/python" ]; then
        echo "❌ Failed to create conda environment!"
        echo "Please check available disk space and permissions."
        exit 1
    fi
}

# Check if environment exists and is valid
if [ -f "$ENV_PATH/bin/python" ]; then
    echo "✅ comfyui environment already exists, checking Python version..."
    PYTHON_VERSION=$("$ENV_PATH/bin/python" --version 2>&1 | cut -d' ' -f2 | cut -d. -f1-2)
    if [ "$PYTHON_VERSION" != "3.12" ]; then
        echo "⚠️ Existing environment uses Python $PYTHON_VERSION, recreating with 3.12..."
        conda remove --name "$ENV_NAME" --all -y
        create_environment
        echo "✅ Recreated comfyui environment with Python 3.12"
    else
        echo "✅ Existing environment has Python 3.12"
    fi
else
    create_environment
    echo "✅ Created comfyui environment with Python 3.12"
fi

# Verify activation script exists
if [ ! -f "$ENV_PATH/bin/activate" ]; then
    echo "❌ Environment activation script not found: $ENV_PATH/bin/activate"
    echo "Contents of bin directory:"
    ls -l "$ENV_PATH/bin"
    echo "Attempting to repair environment..."
    conda install --prefix "$ENV_PATH" conda-env -y
    if [ ! -f "$ENV_PATH/bin/activate" ]; then
        echo "❌ Repair failed! Please check Conda installation"
        exit 1
    else
        echo "✅ Environment repaired successfully"
    fi
fi

echo "
----------------------------------------
🔧 Setting up comfyui environment...
----------------------------------------"
echo "🔄 Activating comfyui environment..."

# Activate environment correctly
source /workspace/miniconda3/bin/activate "$ENV_NAME"

# Verify activation
if [ -z "$CONDA_PREFIX" ] || [ "$CONDA_PREFIX" != "$ENV_PATH" ]; then
    echo "❌ Failed to activate comfyui environment!"
    echo "Current Python: $(which python)"
    echo "Expected path: $ENV_PATH/bin/python"
    echo "CONDA_PREFIX: $CONDA_PREFIX"
    exit 1
else
    echo "✅ Activated environment: $CONDA_PREFIX"
    echo "Python version: $(python --version)"
fi

# Install system dependencies for Python 3.12 support
echo "
----------------------------------------
🔧 Installing system dependencies...
----------------------------------------"
sudo apt update -qq
sudo apt install -y aria2 jq wget build-essential python3.12-dev

echo "
----------------------------------------
📦 Installing ComfyUI requirements with Python 3.12...
----------------------------------------"
cd /workspace/ComfyUI

# Ensure pip is updated
python -m pip install --upgrade pip
python -m pip install --no-cache-dir -r requirements.txt

echo "
----------------------------------------
📦 Installing ComfyUI-Manager requirements...
----------------------------------------"
cd custom_nodes/ComfyUI-Manager
python -m pip install --no-cache-dir -r requirements.txt

# Return to base environment
conda deactivate

echo "
========================================
✨ Setup complete! ✨
========================================
"
