#!/usr/bin/env bash
set -euo pipefail

# Deploy to Google Cloud Run: build image, push to Artifact Registry, deploy.
# Requires: gcloud CLI, Docker, and a GCP project with Cloud Run + Artifact Registry enabled.
#
# Usage:
#   export GCP_PROJECT=your-project-id
#   export GCP_REGION=us-central1
#   ./deploy.sh
#
# Optional:
#   SERVICE_NAME  - Cloud Run service name (default: candidate-summary)
#   REPO_NAME     - Artifact Registry repo name (default: candidate-summary)

GCP_PROJECT="${GCP_PROJECT:?Set GCP_PROJECT to your Google Cloud project ID}"
GCP_REGION="${GCP_REGION:-us-central1}"
SERVICE_NAME="${SERVICE_NAME:-candidate-summary}"
REPO_NAME="${REPO_NAME:-candidate-summary}"

IMAGE="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT}/${REPO_NAME}/${SERVICE_NAME}:latest"

echo "Building Docker image for Cloud Run (linux/amd64)..."
docker build --platform linux/amd64 -t "$IMAGE" .

echo "Configuring Docker for Artifact Registry..."
gcloud auth configure-docker "${GCP_REGION}-docker.pkg.dev" --quiet

echo "Pushing image to Artifact Registry..."
docker push "$IMAGE"

echo "Deploying to Cloud Run..."
gcloud run deploy "$SERVICE_NAME" \
  --image "$IMAGE" \
  --platform managed \
  --region "$GCP_REGION" \
  --project "$GCP_PROJECT" \
  --allow-unauthenticated

echo "Done. Service URL:"
gcloud run services describe "$SERVICE_NAME" \
  --platform managed \
  --region "$GCP_REGION" \
  --project "$GCP_PROJECT" \
  --format 'value(status.url)'
