#!/usr/bin/env bash
set -e

IMAGE=$1

if [ -z "$IMAGE" ]; then
  echo "Usage: ./test_cuda.sh <image_tag>"
  exit 1
fi

echo "=== Testing Image: $IMAGE ==="

docker run --rm --gpus all $IMAGE nvcc --version

docker run --rm --gpus all $IMAGE python3 -c "
import torch
print('CUDA Available:', torch.cuda.is_available())
if torch.cuda.is_available():
    print('Device Name:', torch.cuda.get_device_name(0))
" || echo "PyTorch not present, testing via CUDA Driver runtime..."

docker run --rm $IMAGE ros2 pkg list | grep -E "fast_lio|livox_ros_driver2"