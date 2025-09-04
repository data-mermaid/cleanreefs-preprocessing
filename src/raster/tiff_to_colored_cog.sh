#!/usr/bin/env bash


WORKING_DIR="working_$$"
SRC_TIFF_S3_PATH="$1"
TARG_TIFF_S3_PATH="$2"

COLOR_TABLE_FILE="colortable.txt"

SRC_TIFF_PATH="$WORKING_DIR/source.tif"
WARPED_TIFF_PATH="$WORKING_DIR/warped.tif"
TARG_TIFF_PATH="$WORKING_DIR/target.tif"

## Check if all positional arguments are passed
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <source_tiff_s3_path> <target_tiff_s3_path>"
    exit 1
fi


mkdir -p "$WORKING_DIR"

aws s3 cp "$SRC_TIFF_S3_PATH" $SRC_TIFF_PATH

gdalwarp \
    -t_srs "EPSG:3857" \
    $SRC_TIFF_PATH \
    $WARPED_TIFF_PATH

gdaldem color-relief \
    -of COG \
    -co "COMPRESS=DEFLATE" \
    -co "NUM_THREADS=ALL_CPUS" \
    -co PREDICTOR=2 \
    -co BLOCKSIZE=512 \
    --config GDAL_CACHEMAX 2048 \
    -co "BIGTIFF=YES" \
    -nearest_color_entry \
    -alpha \
    $WARPED_TIFF_PATH $COLOR_TABLE_FILE $TARG_TIFF_PATH

aws s3 cp $TARG_TIFF_PATH $TARG_TIFF_S3_PATH

# rm -R $WORKING_DIR