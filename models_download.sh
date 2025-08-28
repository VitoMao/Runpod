# Download models
echo "
----------------------------------------
📥 Downloading models...
----------------------------------------"

MODELS_JSON="/tmp/models.json"
MODELS_URL="https://raw.githubusercontent.com/VitoMao/Runpod/main/models.json"

cd /workspace/ComfyUI
wget -q -O "$MODELS_JSON" "$MODELS_URL"

# Create required directories
jq -r '.[].path' "$MODELS_JSON" | xargs -I {} dirname {} | sort -u | xargs -I {} mkdir -p {}

# Convert JSON to aria2 input format
jq -r '.[] | "\(.url)\n  out=\(.path)"' "$MODELS_JSON" > /tmp/aria2_input.txt

# Batch download
aria2c -x 16 -s 16 -k 1M \
  --max-concurrent-downloads=3 \
  --max-tries=5 \
  --continue=true \
  --input-file=/tmp/aria2_input.txt

# Verify downloads
downloaded=$(find /workspace/ComfyUI/models -type f | wc -l)
expected=$(jq 'length' "$MODELS_JSON")
if [ "$downloaded" -eq "$expected" ]; then
  echo "✅ All $downloaded models downloaded successfully!"
else
  echo "❌ Download incomplete! Downloaded: $downloaded, Expected: $expected"
fi

# Final Python version check
echo "
----------------------------------------
🐍 Final environment check:
----------------------------------------"
conda activate comfyui
python --version
conda deactivate