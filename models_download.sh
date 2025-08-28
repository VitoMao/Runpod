#!/usr/bin/env bash
set -Eeuo pipefail

echo "
----------------------------------------
📥 Uploading models.json...
----------------------------------------"

ROOT="/workspace/ComfyUI"
cd "$ROOT"

# Assume the models.json file has been uploaded to /workspace/ComfyUI
MODELS_JSON="/workspace/ComfyUI/models.json"

# Create required directories (handles spaces safely)
while IFS= read -r p; do
  mkdir -p "$(dirname "$p")"
done < <(jq -r '.[].path' "$MODELS_JSON")

# Build aria2 input: use dir=<dirname> and out=<basename>
ARIA_IN="/tmp/aria2_input.txt"
jq -r '
  .[] |
  . as $i |
  "\($i.url)\n  dir=\(($i.path | split("/")[:-1] | join("/")))\n  out=\(($i.path | split("/")[-1]))\n"
' "$MODELS_JSON" > "$ARIA_IN"

# Move any mistakenly nested files from a previous run (caused by using full path in out=)
if [ -d "$ROOT/workspace/ComfyUI/models" ]; then
  echo "⚠️  Found nested downloads from a previous run; migrating..."
  while IFS= read -r -d '' f; do
    rel="${f#"$ROOT/workspace/ComfyUI/"}"          # strip the duplicated prefix
    dest="$ROOT/$rel"
    mkdir -p "$(dirname "$dest")"
    mv -n "$f" "$dest"
  done < <(find "$ROOT/workspace/ComfyUI/models" -type f -print0 || true)
  # Clean up empty dirs
  find "$ROOT/workspace" -type d -empty -delete || true
fi

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

# Robust verification: report missing and extras
echo "
----------------------------------------
🔎 Verifying downloads...
----------------------------------------"
mapfile -t EXPECTED < <(jq -r '.[].path' "$MODELS_JSON" | sort -u)
mapfile -t FOUND < <(find "$ROOT/models" -type f -printf '%P\n' | sed 's#^#models/#' | sort -u || true)

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

# Final Python / conda check
echo "
----------------------------------------
🐍 Final environment check:
----------------------------------------"
if command -v conda >/dev/null 2>&1; then
  # initialize conda for non-interactive shells
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
