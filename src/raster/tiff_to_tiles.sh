#!/usr/bin/env bash

set -e

# Server setup
# - Instance type: c8g.48xlarge
# - OS: Ubuntu
# - Architecture: arm64
# - Key Pair: compute-ec2
# - Security Group: sg-0fe1a43953882f7b0
# - Volume type: gp3
# - Volume size: 1000 GiB
# - Volume throughput: 1000
# - Volume IOPS: 16000
# - IAM instance profile: ProcessingRole

REGION=ap-southeast-2
INSTANCE_ID=$1
YEAR=$2
SRC_TIFF_S3_PATH=$3
TILES_S3_PATH=$4

if [ -z "$INSTANCE_ID" ] || [ -z "$YEAR" ] || [ -z "$SRC_TIFF_S3_PATH" ] || [ -z "$TILES_S3_PATH" ]; then
    echo "Usage: $0 <instance_id> <year> <tiff_s3_path> <tiles_s3_path>"
    exit 1
fi

# *******
# Setup *
# *******

apt update
apt install -y unzip gdal-bin moreutils htop

curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

wget "https://github.com/peak/s5cmd/releases/download/v2.3.0/s5cmd_2.3.0_Linux-arm64.tar.gz"
tar -xzf s5cmd_2.3.0_Linux-arm64.tar.gz
mv s5cmd /usr/local/bin/

# File Descriptors
ulimit -n 1048576
sysctl -w fs.file-max=2000000

# Set the range of ephemeral ports for outgoing connections (more concurrent sockets)
sysctl -w net.ipv4.ip_local_port_range="15000 65000"
# Reduce the time sockets stay in FIN-WAIT-2 state (frees up resources faster)
sysctl -w net.ipv4.tcp_fin_timeout=15
# Increase maximum receive buffer size for network sockets (improves throughput)
sysctl -w net.core.rmem_max=134217728
# Increase maximum send buffer size for network sockets (improves throughput)
sysctl -w net.core.wmem_max=134217728
# Raise the maximum number of packets allowed to queue on the network interface
sysctl -w net.core.netdev_max_backlog=30000
# Use BBR TCP congestion control for better bandwidth and latency
sysctl -w net.ipv4.tcp_congestion_control
# Set min, default, and max TCP receive buffer sizes
# (improves throughput for high-latency connections)
sysctl -w net.ipv4.tcp_rmem="4096 131072 134217728"
# Set min, default, and max TCP send buffer sizes
# (improves throughput for high-latency connections)
sysctl -w net.ipv4.tcp_wmem="4096 65536


# **************
# Process Data *
# **************    
mkdir -p data
aws cp $SRC_TIFF_S3_PATH ./data
TIFF_NAME=$(basename "$SRC_TIFF_S3_PATH")

gdal2tiles.py \
    -z 0-12 \
    -s EPSG:3857 \
    -r bilinear \
    -a 0,0,0 \
    --xyz \
    --processes=$(nproc) \
    "data/$TIFF_NAME" \
    data/output_tiles/

if [ $? -ne 0 ]; then
    echo "ERROR: gdal2tiles failed with exit code $?"
    exit 1
fi

s5cmd \
    --numworkers 16384 \
    --retry-count 20 \
    --log error \
    cp \
    './data/ouput_tiles/**' \
    '$TILES_S3_PATH'

if [ $? -ne 0 ]; then
    echo "ERROR: s5cmd failed with exit code $?"
    exit 1
fi

# *********
# Cleanup *
# *********
echo "All operations completed successfully. Terminating instance..."
aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION