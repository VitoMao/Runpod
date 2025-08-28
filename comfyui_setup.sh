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

# Download and install Miniconda
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

# Initialize conda
echo "
----------------------------------------
🐍 Initializing conda...
----------------------------------------"
source /workspace/miniconda3/bin/activate
conda init bash > /dev/null 2>&1
eval "$(/workspace/miniconda3/bin/conda shell.bash hook)"

# Update conda
echo "Updating conda..."
conda update -n base -c defaults conda -y

# Clone repositories
echo "
----------------------------------------
📥 Cloning repositories...
----------------------------------------"
if [ ! -d "/workspace/ComfyUI/.git" ]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI
else
    echo "✅ ComfyUI repository already exists, skipping clone..."
fi

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

# Create environment with conda package included
create_environment() {
    echo "🔄 Creating new environment '$ENV_NAME' with Python 3.12 and conda"
    conda create --name "$ENV_NAME" python=3.12 conda -y
    
    # Verify critical files exist
    if [ ! -f "$ENV_PATH/bin/activate" ]; then
        echo "❌ Critical error: Activation script still missing after creation!"
        echo "Contents of $ENV_PATH/bin:"
        ls -l "$ENV_PATH/bin"
        echo "Please check disk space and permissions"
        exit 1
    fi
}

# Environment setup logic
if [ -d "$ENV_PATH" ]; then
    echo "ℹ️ Existing environment detected"
    
    if [ -f "$ENV_PATH/bin/activate" ]; then
        echo "✅ Activation script exists, verifying Python version..."
        PYTHON_VERSION=$(conda run -n $ENV_NAME python --version 2>&1 | cut -d' ' -f2 | cut -d. -f1-2)
        if [ "$PYTHON_VERSION" != "3.12" ]; then
            echo "⚠️ Wrong Python version ($PYTHON_VERSION), recreating environment..."
            conda remove --name "$ENV_NAME" --all -y
            create_environment
        else
            echo "✅ Environment is valid with Python 3.12"
        fi
    else
        echo "⚠️ Missing activation script, recreating environment..."
        rm -rf "$ENV_PATH"
        create_environment
    fi
else
    create_environment
fi

echo "
----------------------------------------
🔧 Activating environment...
----------------------------------------"
source /workspace/miniconda3/bin/activate "$ENV_NAME"

# Verify activation
if [ -z "$CONDA_PREFIX" ] || [ "$CONDA_PREFIX" != "$ENV_PATH" ]; then
    echo "❌ Activation failed! Trying alternative method..."
    export PATH="$ENV_PATH/bin:$PATH"
    export CONDA_DEFAULT_ENV="$ENV_NAME"
    export CONDA_PREFIX="$ENV_PATH"
    
    if [ "$(python -c 'import sys; print(sys.executable)')" != "$ENV_PATH/bin/python" ]; then
        echo "❌ FATAL: Could not activate environment"
        echo "Python path: $(which python)"
        exit 1
    fi
fi
echo "✅ Activated $CONDA_PREFIX"

# Install system dependencies
echo "
----------------------------------------
🔧 Installing system dependencies...
----------------------------------------"
sudo apt update -qq
sudo apt install -y aria2 jq wget build-essential python3.12-dev

# Install Python dependencies
echo "
----------------------------------------
📦 Installing Python dependencies...
----------------------------------------"
cd /workspace/ComfyUI
pip install --upgrade pip
pip install --no-cache-dir -r requirements.txt

cd custom_nodes/ComfyUI-Manager
pip install --no-cache-dir -r requirements.txt

echo "
========================================
✨ Setup complete!  ✨
========================================
"
