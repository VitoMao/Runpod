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

# Install system dependencies
echo "
----------------------------------------
🔧 Installing system dependencies...
----------------------------------------"
if command -v apt-get >/dev/null 2>&1; then
  SUDO=""
  command -v sudo >/dev/null 2>&1 && SUDO="sudo"
  export DEBIAN_FRONTEND=noninteractive
  $SUDO apt-get update -qq
  $SUDO apt-get install -y --no-install-recommends git wget aria2 jq build-essential
fi

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

# Initialize conda for this shell (non-interactive friendly)
echo "
----------------------------------------
🐍 Initializing conda...
----------------------------------------"
. /workspace/miniconda3/etc/profile.d/conda.sh
# (Optional) keep init out of dotfiles in CI/containers
# conda init bash > /dev/null 2>&1  # not needed here

# Accept Anaconda ToS for defaults channels (newer installers include the plugin)
# Fall back gracefully if the plugin isn't present.
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main || true
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r || true

# Clone ComfyUI repository
echo "
----------------------------------------
📥 Cloning ComfyUI repository...
----------------------------------------"
if [ ! -d "/workspace/ComfyUI/.git" ]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI
else
    echo "✅ ComfyUI repository already exists, skipping clone..."
fi

# Clone ComfyUI-Manager repository
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
ENV_PATH="/workspace/miniconda3/envs/comfyui"

# Clean up a broken dir (no python in it)
if [ -d "$ENV_PATH" ] && [ ! -x "$ENV_PATH/bin/python" ]; then
  echo "⚠️ Removing invalid environment directory: $ENV_PATH"
  rm -rf "$ENV_PATH"
fi

if [ ! -x "$ENV_PATH/bin/python" ]; then
  conda create -p "$ENV_PATH" -y python=3.12
else
  # Recreate if not on 3.12
  PYTHON_VERSION="$("$ENV_PATH/bin/python" -c 'import sys;print(".".join(map(str,sys.version_info[:2])))')"
  if [ "$PYTHON_VERSION" != "3.12" ]; then
    echo "⚠️ Existing env uses Python $PYTHON_VERSION, recreating with 3.12..."
    rm -rf "$ENV_PATH"
    conda create -p "$ENV_PATH" -y python=3.12
  fi
fi

echo "🔄 Activating comfyui environment..."
# Correct activation command
conda activate "$ENV_PATH" || { echo "❌ Failed to activate environment!"; exit 1; }

# Verify activation
if [ "$(command -v python)" != "$ENV_PATH/bin/python" ]; then
  echo "❌ Conda activation did not set the expected Python."
  exit 1
fi

echo "Activated Python: $(which python)"
python --version

# Install Python requirements for ComfyUI
echo "
----------------------------------------
📦 Installing ComfyUI requirements with Python 3.12...
----------------------------------------"
cd /workspace/ComfyUI
python -m pip install --upgrade pip
python -m pip install --no-cache-dir -r requirements.txt

# Install Python requirements for ComfyUI-Manager
echo "
----------------------------------------
📦 Installing ComfyUI-Manager requirements...
----------------------------------------"
cd "$MANAGER_DIR"
python -m pip install --no-cache-dir -r requirements.txt

# Return to base environment
conda deactivate

echo "
========================================
✨ Setup complete!  ✨
========================================
"
