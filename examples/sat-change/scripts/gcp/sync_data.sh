#!/bin/bash
# Sync data between local and GCS
# Usage: ./sync_data.sh [upload|download] [extracted|processed|checkpoints]

set -e

BUCKET_NAME="${GCS_BUCKET:-satchange-data}"
ACTION="${1:-download}"
DATA_TYPE="${2:-extracted}"

case "$DATA_TYPE" in
    extracted)
        LOCAL_PATH="data/extracted"
        GCS_PATH="gs://$BUCKET_NAME/data/extracted"
        ;;
    processed)
        LOCAL_PATH="data/processed"
        GCS_PATH="gs://$BUCKET_NAME/data/processed"
        ;;
    checkpoints)
        LOCAL_PATH="checkpoints"
        GCS_PATH="gs://$BUCKET_NAME/checkpoints"
        ;;
    *)
        echo "Unknown data type: $DATA_TYPE"
        echo "Usage: $0 [upload|download] [extracted|processed|checkpoints]"
        exit 1
        ;;
esac

case "$ACTION" in
    upload)
        echo "Uploading $LOCAL_PATH to $GCS_PATH..."
        gsutil -m rsync -r "$LOCAL_PATH" "$GCS_PATH"
        echo "Upload complete!"
        ;;
    download)
        echo "Downloading $GCS_PATH to $LOCAL_PATH..."
        mkdir -p "$LOCAL_PATH"
        gsutil -m rsync -r "$GCS_PATH" "$LOCAL_PATH"
        echo "Download complete!"
        ;;
    *)
        echo "Unknown action: $ACTION"
        echo "Usage: $0 [upload|download] [extracted|processed|checkpoints]"
        exit 1
        ;;
esac
