#!/usr/bin/env bash
set -Eeuo pipefail

echo "
----------------------------------------
📥 Downloading models...
----------------------------------------"

MODELS_DIR="/workspace/models"
mkdir -p "$MODELS_DIR"
cd "$MODELS_DIR"

MODELS_JSON="/tmp/models.json"
MODELS_URL="https://raw.githubusercontent.com/VitoMao/Runpod/main/models.json"

wget -q -O "$MODELS_JSON" "$MODELS_URL"

# Create required directories with proper object filtering
while IFS= read -r p; do
  mkdir -p "$(dirname "$p")"
done < <(jq -r '.[] | select(type=="object" and has("path")) | .path' "$MODELS_JSON")

# Build aria2 input file with robust filtering
ARIA_IN="/tmp/aria2_input.txt"
jq -r '
  .[] | 
  select(type=="object" and has("path") and has("url")) | 
  "\(.url)\n  dir=\(.path | if test("/") then sub("/[^/]*$"; "") else "." end)\n  out=\(.path | split("/")[-1])\n"
' "$MODELS_JSON" > "$ARIA_IN"

# Batch download
aria2c -x 16 -s 16 -k 1M \
  --max-concurrent-downloads=3 \
  --max-tries=5 \
  --continue=true \
  --allow-overwrite=true \
  --auto-file-renaming=false \
  --console-log-level=warn \
  -l /tmp/aria2.log \
  --input-file="$ARIA_IN"

# Robust verification
echo "
----------------------------------------
🔎 Verifying downloads...
----------------------------------------"
mapfile -t EXPECTED < <(jq -r '.[] | select(type=="object" and has("path")) | .path' "$MODELS_JSON" | sort -u)
mapfile -t FOUND < <(find . -type f -printf '%P\n' | sort -u)

# Print missing
missing=()
for p in "${EXPECTED[@]}"; do
  if ! printf '%s\n' "${FOUND[@]}" | grep -Fxq "$p"; then
    missing+=("$p")
  fi
done

# Print extras
extras=()
for f in "${FOUND[@]}"; do
  if ! printf '%s\n' "${EXPECTED[@]}" | grep -Fxq "$f"; then
    extras+=("$f")
  fi
done

if [ "${#missing[@]}" -eq 0 ]; then
  echo "✅ All expected files present: ${#EXPECTED[@]}"
else
  echo "❌ Missing ${#missing[@]} of ${#EXPECTED[@]} expected files:"
  printf '  - %s\n' "${missing[@]}"
fi

if [ "${#extras[@]}" -gt 0 ]; then
  echo "ℹ️  Extra files found (not in models.json):"
  printf '  - %s\n' "${extras[@]}"
fi

# Final Python/conda check
echo "
----------------------------------------
🐍 Final environment check:
----------------------------------------"
if command -v conda >/dev/null 2>&1; then
  eval "$(conda shell.bash hook)"
  if conda info --envs | grep -q '^comfyui[[:space:]]'; then
    conda activate comfyui
    python --version
    conda deactivate
  else
    echo "⚠️  conda found, but env 'comfyui' is missing. Using system Python:"
    python --version
  fi
else
  echo "⚠️  conda not found. Using system Python:"
  python --version
fi

echo "
----------------------------------------
📄 aria2 log (tail):
----------------------------------------"
tail -n 50 /tmp/aria2.log || true
