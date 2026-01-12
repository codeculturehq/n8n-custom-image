#!/usr/bin/env bash
set -euo pipefail

root_dir="$(pwd)"
vendor_dir="vendor/n8n"

# Detect n8n major version from package.json
if [[ -f "$vendor_dir/package.json" ]]; then
  version=$(grep '"version"' "$vendor_dir/package.json" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
  major_version="${version%%.*}"
  echo "Detected n8n version: $version (major: $major_version)"
else
  echo "Error: Cannot find vendor/n8n/package.json" >&2
  exit 1
fi

# Select patch directory based on major version
if [[ "$major_version" == "2" ]] && [[ -d "patches/n8n/v2" ]]; then
  patch_dir="patches/n8n/v2"
  echo "Using v2.x patches from: $patch_dir"
elif [[ "$major_version" == "1" ]] && [[ -d "patches/n8n/v1" ]]; then
  patch_dir="patches/n8n/v1"
  echo "Using v1.x patches from: $patch_dir"
elif [[ -d "patches/n8n/v$major_version" ]]; then
  patch_dir="patches/n8n/v$major_version"
  echo "Using v$major_version.x patches from: $patch_dir"
else
  # Fallback to root patches directory (legacy)
  patch_dir="patches/n8n"
  echo "Warning: No version-specific patches found, using legacy patches from: $patch_dir"
fi

# Apply patches
patch_count=0
for p in "$patch_dir"/*.patch; do
  if [[ -f "$p" ]]; then
    echo "Applying: $(basename "$p")"
    git -C "$vendor_dir" apply "$root_dir/$p"
    ((patch_count++))
  fi
done

if [[ $patch_count -eq 0 ]]; then
  echo "Warning: No patches found in $patch_dir"
else
  echo "Successfully applied $patch_count patches"
fi
