#!/bin/bash

# Grant all necessary IAM permissions for Firebase Cloud Functions deployment
# Run this script in Google Cloud Shell or with gcloud CLI authenticated

PROJECT_ID="sweatmark-v1"
USER_EMAIL="tolu@clarivue.io"

echo "Granting IAM permissions for project: $PROJECT_ID"
echo "User: $USER_EMAIL"
echo ""

# Cloud Functions Admin - for deploying and managing functions
echo "1. Granting roles/cloudfunctions.admin..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:$USER_EMAIL" \
  --role="roles/cloudfunctions.admin" \
  --quiet

# Cloud Run Admin - for HTTP functions with public invokers
echo "2. Granting roles/run.admin..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:$USER_EMAIL" \
  --role="roles/run.admin" \
  --quiet

# Service Account User - to act as service accounts
echo "3. Granting roles/iam.serviceAccountUser..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:$USER_EMAIL" \
  --role="roles/iam.serviceAccountUser" \
  --quiet

# Cloud Build Editor - for building function containers
echo "4. Granting roles/cloudbuild.builds.editor..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:$USER_EMAIL" \
  --role="roles/cloudbuild.builds.editor" \
  --quiet

# Storage Admin - for uploading function code
echo "5. Granting roles/storage.admin..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:$USER_EMAIL" \
  --role="roles/storage.admin" \
  --quiet

# Secret Manager Admin - for managing secrets used by functions
echo "6. Granting roles/secretmanager.admin..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:$USER_EMAIL" \
  --role="roles/secretmanager.admin" \
  --quiet

# Artifact Registry Admin - for container images
echo "7. Granting roles/artifactregistry.admin..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:$USER_EMAIL" \
  --role="roles/artifactregistry.admin" \
  --quiet

echo ""
echo "✅ All permissions granted successfully!"
echo ""
echo "Now run: firebase deploy --only functions"
