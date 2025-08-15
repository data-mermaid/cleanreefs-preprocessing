#!/bin/bash
set -euo pipefail

S3_PREFIX="/vsis3/gpw-coastal-pollution-model-data-public-0001/inputs/land/global/global_watershed_bas/global_watershed_bas^0/"

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <output.pmtiles> <input.parquet>"
    exit 1
fi

OUTPUT_FILE="$1"
INPUT_FILE="$2"

INPUT_S3_PATH="${S3_PREFIX}${INPUT_FILE}"
OUTPUT_S3_PATH="${S3_PREFIX}${OUTPUT_FILE}"

echo "Running ogr2ogr from:"
echo "  Input:  ${INPUT_S3_PATH}"
echo "  Output: ${OUTPUT_S3_PATH}"

ogr2ogr -dsco MINZOOM=0 -dsco MAXZOOM=10 -f "PMTiles" "${OUTPUT_S3_PATH}" "${INPUT_S3_PATH}" -progress
