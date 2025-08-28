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

# Create conda environment with Python 3.12
echo "
----------------------------------------
🌟 Creating conda environment with Python 3.12...
----------------------------------------"
if ! conda info --envs | grep -q "comfyui"; then
    conda create -n comfyui python=3.12 -y
    echo "✅ Created comfyui environment with Python 3.12"
else
    echo "✅ comfyui environment already exists, skipping creation..."
    # Check Python version in existing environment
    PYTHON_VERSION=$(conda run -n comfyui python --version 2>&1 | cut -d' ' -f2 | cut -d. -f1-2)
    if [ "$PYTHON_VERSION" != "3.12" ]; then
        echo "⚠️ Existing environment uses Python $PYTHON_VERSION, recreating with 3.12..."
        conda env remove -n comfyui -y
        conda create -n comfyui python=3.12 -y
        echo "✅ Recreated comfyui environment with Python 3.12"
    fi
fi

# Setup comfyui environment
echo "
----------------------------------------
🔧 Setting up comfyui environment...
----------------------------------------"
echo "🔄 Activating comfyui environment..."
set -x  # Enable debug mode to see each command
conda activate comfyui
RESULT=$?
echo "Activation exit code: $RESULT"
if [ "$CONDA_DEFAULT_ENV" != "comfyui" ]; then
    echo "❌ Failed to activate comfyui environment! Current env: $CONDA_DEFAULT_ENV"
    exit 1
fi
echo "✅ Successfully activated comfyui environment"

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

# Ensure pip is up-to-date
pip install --upgrade pip

# Install requirements with Python 3.12
pip install --no-cache-dir -r requirements.txt

echo "
----------------------------------------
📦 Installing ComfyUI-Manager requirements...
----------------------------------------"
cd custom_nodes/ComfyUI-Manager
pip install --no-cache-dir -r requirements.txt

# Return to base environment
conda deactivate

echo "
========================================
✨ Setup complete! ✨
========================================
"
