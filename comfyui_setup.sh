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

# 关键修复：使用明确的路径创建环境
echo "
----------------------------------------
🌟 Creating conda environment with Python 3.12...
----------------------------------------"
ENV_PATH="/workspace/miniconda3/envs/comfyui"

# 删除可能存在的无效环境
if [ -d "$ENV_PATH" ] && [ ! -f "$ENV_PATH/bin/python" ]; then
    echo "⚠️ Removing invalid environment directory: $ENV_PATH"
    rm -rf "$ENV_PATH"
fi

# Accept Conda's terms of service for the main and R channels
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

# 检查是否存在有效的Python环境
if [ ! -f "$ENV_PATH/bin/python" ]; then
    echo "🔄 Creating new conda environment at $ENV_PATH"
    
    # 确保环境目录不存在
    if [ -d "$ENV_PATH" ]; then
        rm -rf "$ENV_PATH"
    fi
    
    # 使用明确的路径创建环境
    conda create -p "$ENV_PATH" python=3.12 -y
    
    # 验证环境创建
    if [ ! -f "$ENV_PATH/bin/python" ]; then
        echo "❌ Failed to create conda environment!"
        echo "Please check available disk space and permissions."
        exit 1
    fi
    
    echo "✅ Created comfyui environment with Python 3.12"
else
    echo "✅ comfyui environment already exists, checking Python version..."
    
    # 检查Python版本
    PYTHON_VERSION=$("$ENV_PATH/bin/python" --version 2>&1 | cut -d' ' -f2 | cut -d. -f1-2)
    if [ "$PYTHON_VERSION" != "3.12" ]; then
        echo "⚠️ Existing environment uses Python $PYTHON_VERSION, recreating with 3.12..."
        rm -rf "$ENV_PATH"
        conda create -p "$ENV_PATH" python=3.12 -y
        
        # 验证环境创建
        if [ ! -f "$ENV_PATH/bin/python" ]; then
            echo "❌ Failed to recreate conda environment!"
            exit 1
        fi
        
        echo "✅ Recreated comfyui environment with Python 3.12"
    else
        echo "✅ Existing environment has Python 3.12"
    fi
fi

# Verify the environment creation by checking the activate script
if [ ! -f "$ENV_PATH/bin/activate" ]; then
    echo "❌ Environment activation script not found: $ENV_PATH/bin/activate"
    exit 1
fi

# 设置环境变量
export CONDA_ENV_PATH="$ENV_PATH"

echo "
----------------------------------------
🔧 Setting up comfyui environment...
----------------------------------------"
echo "🔄 Activating comfyui environment..."
set -x  # Enable debug mode to see each command

# 使用直接路径激活环境
source "$ENV_PATH/bin/activate"

# 验证激活状态
if [ ! -f "$ENV_PATH/bin/activate" ]; then
    echo "❌ Environment activation script not found: $ENV_PATH/bin/activate"
    exit 1
fi

# 显式设置环境变量
export PATH="$ENV_PATH/bin:$PATH"
export CONDA_DEFAULT_ENV="comfyui"
export CONDA_PREFIX="$ENV_PATH"

# 检查Python路径
which python
python --version

RESULT=$?
echo "Activation exit code: $RESULT"
if [ "$(python -c 'import sys; print(sys.executable)')" != "$ENV_PATH/bin/python" ]; then
    echo "❌ Failed to activate comfyui environment!"
    echo "Current Python path: $(which python)"
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

# 确保pip是当前环境的
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
✨ Setup complete!  ✨
========================================
"
