#!/bin/bash
set -e

echo "Building and pushing Docker image: $IMAGE_URL"

# Ensure we're in the right directory
cd "$(dirname "$0")/.."

# Build Docker image
echo "Building image..."
docker build --tag "$IMAGE_URL" .

# Push Docker image
echo "Pushing image to Artifact Registry..."
docker push "$IMAGE_URL"

echo "Docker image successfully pushed: $IMAGE_URL"

