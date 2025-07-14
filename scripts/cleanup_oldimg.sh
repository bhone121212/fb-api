#!/bin/bash
set -e
export BUILDAH_ISOLATION=chroot

IMAGE_NAME="localhost/bhonebhone/fb-api"
KEEP_COUNT=5

echo "🧹 Cleaning up old images for $IMAGE_NAME, keeping only the latest $KEEP_COUNT"

buildah images --json | jq -r '
  .[] | select(.Repository == "'"$IMAGE_NAME"'") | "\(.Created) \(.Id)"
' | sort -nr | awk '{print $2}' > all_ids.txt

head -n $KEEP_COUNT all_ids.txt > keep_ids.txt

echo "🆕 Keeping these image IDs:"
cat keep_ids.txt

echo "🗑️ Checking for deletable old image IDs:"
grep -Fxv -f keep_ids.txt all_ids.txt > delete_ids.txt || true
cat delete_ids.txt

if [ ! -s delete_ids.txt ]; then
  echo "✅ No old images to delete."
fi

while read -r id; do
    if [ -n "$id" ]; then
        echo "🗑️ Deleting image: $id"
        sudo buildah rmi -f "$id" || echo "⚠️ Could not delete $id"
    fi
done < delete_ids.txt

rm -f all_ids.txt keep_ids.txt delete_ids.txt
