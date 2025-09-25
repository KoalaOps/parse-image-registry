# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-25

### Added
- Initial release of parse-image-registry action
- Support for parsing Docker image URLs from multiple registries:
  - AWS ECR (Elastic Container Registry)
  - AWS ECR Public
  - GCP Artifact Registry
  - GCP Container Registry (legacy)
  - Azure Container Registry
  - GitHub Container Registry (ghcr.io)
  - Docker Hub
  - Generic private registries
- Automatic detection of cloud provider from image URL
- Extraction of account/project, region, and registry information
- Comprehensive output variables for integration with other actions
- Environment variable exports for convenience