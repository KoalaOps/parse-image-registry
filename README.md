# Parse Image Registry Action

A GitHub Action that parses Docker image URLs to automatically detect cloud providers and extract registry information. This enables seamless authentication and registry configuration across different cloud providers and container registries.

## Why Use This Action?

In monorepo setups or multi-cloud environments, different services may use different container registries. This action simplifies CI/CD workflows by:

- **Eliminating hardcoded registry logic** - Automatically detects the registry type from the image URL
- **Supporting multi-cloud deployments** - Different services can use different cloud providers
- **Simplifying authentication** - Provides structured outputs that work seamlessly with authentication actions
- **Reducing configuration complexity** - One workflow can handle multiple registry types

## Features

- 🔍 **Automatic Provider Detection** - Intelligently identifies the cloud provider from image URL patterns
- 🌍 **Multi-Cloud Support** - Works with AWS, GCP, Azure, GitHub, Docker Hub, and generic registries
- 📦 **Comprehensive Registry Support**:
  - AWS ECR (Elastic Container Registry)
  - AWS ECR Public
  - GCP Artifact Registry
  - GCP Container Registry (legacy)
  - Azure Container Registry
  - GitHub Container Registry (ghcr.io)
  - Docker Hub (including official images)
  - Generic private registries
- 🔧 **Rich Output Data** - Provides structured information for downstream actions
- 🏷️ **Environment Variables** - Exports parsed values for script convenience

## Quick Start

### Basic Usage

```yaml
- name: Parse image registry
  id: parse_registry
  uses: KoalaOps/parse-image-registry@v1
  with:
    image: '123456789.dkr.ecr.us-east-1.amazonaws.com/my-service'

- name: Use parsed information
  run: |
    echo "Provider: ${{ steps.parse_registry.outputs.provider }}"
    echo "Account: ${{ steps.parse_registry.outputs.account }}"
    echo "Region: ${{ steps.parse_registry.outputs.region }}"
    echo "Registry: ${{ steps.parse_registry.outputs.registry }}"
```

### Real-World Example: Multi-Cloud Build Pipeline

```yaml
name: Build and Push Image

on:
  workflow_dispatch:
    inputs:
      image:
        description: 'Full image URL (e.g., 123456789.dkr.ecr.us-east-1.amazonaws.com/my-service)'
        required: true

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      # Parse the image URL to determine where to push
      - name: Parse image registry
        id: parse_registry
        uses: KoalaOps/parse-image-registry@v1
        with:
          image: ${{ inputs.image }}
      
      # Authenticate with the detected cloud provider
      - name: Login to registry
        uses: KoalaOps/cloud-login@v1
        with:
          provider: ${{ steps.parse_registry.outputs.provider }}
          account: ${{ steps.parse_registry.outputs.account }}
          region: ${{ steps.parse_registry.outputs.region }}
          login_to_container_registry: true
          registry: ${{ steps.parse_registry.outputs.registry }}
          # Pass all potential credentials - cloud-login uses what's needed
          aws_role_to_assume: ${{ vars.AWS_BUILD_ROLE }}
          gcp_workload_identity_provider: ${{ vars.WIF_PROVIDER }}
          gcp_service_account: ${{ vars.WIF_SERVICE_ACCOUNT }}
          github_token: ${{ secrets.GITHUB_TOKEN }}
      
      # Build and push to the detected registry
      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          push: true
          tags: ${{ inputs.image }}:latest
```

## Inputs

| Input | Description | Required |
|-------|-------------|----------|
| `image` | Full Docker image URL (without tag) | Yes |

## Outputs

| Output | Description | Example |
|--------|-------------|---------|
| `provider` | Cloud provider | `aws`, `gcp`, `azure`, `github`, `dockerhub`, `generic` |
| `account` | Account/Project ID | `123456789`, `my-project`, `myorg` |
| `region` | Region/Location (if applicable) | `us-east-1`, `us-central1` |
| `registry` | Full registry URL | `123456789.dkr.ecr.us-east-1.amazonaws.com` |
| `repository` | Repository/image name | `my-service` |
| `registry_type` | Type of registry | `ecr`, `artifact-registry`, `acr`, `ghcr`, `dockerhub`, `generic` |

## Registry Examples

### AWS ECR
```yaml
with:
  image: '123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app'
# Outputs:
#   provider: aws
#   account: 123456789012
#   region: us-east-1
#   registry: 123456789012.dkr.ecr.us-east-1.amazonaws.com
#   repository: my-app
#   registry_type: ecr
```

### AWS ECR Public
```yaml
with:
  image: 'public.ecr.aws/myalias/my-app'
# Outputs:
#   provider: aws
#   account: myalias
#   region: us-east-1  # ECR Public is always us-east-1
#   registry: public.ecr.aws/myalias
#   repository: my-app
#   registry_type: ecr-public
```

### GCP Artifact Registry
```yaml
with:
  image: 'us-central1-docker.pkg.dev/my-project/my-registry/my-service'
# Outputs:
#   provider: gcp
#   account: my-project
#   region: us-central1
#   registry: us-central1-docker.pkg.dev/my-project/my-registry
#   repository: my-service
#   registry_type: artifact-registry
```

### GCP Container Registry (Legacy)
```yaml
with:
  image: 'gcr.io/my-project/my-app'
# Outputs:
#   provider: gcp
#   account: my-project
#   region: us  # Default region for gcr.io
#   registry: gcr.io/my-project
#   repository: my-app
#   registry_type: gcr
```

### Azure Container Registry
```yaml
with:
  image: 'myregistry.azurecr.io/my-app'
# Outputs:
#   provider: azure
#   account: myregistry
#   region: ''  # Azure doesn't expose region in URL
#   registry: myregistry.azurecr.io
#   repository: my-app
#   registry_type: acr
```

### GitHub Container Registry
```yaml
with:
  image: 'ghcr.io/myorg/my-service'
# Outputs:
#   provider: github
#   account: myorg
#   registry: ghcr.io
#   repository: my-service
#   registry_type: ghcr
```

### Docker Hub
```yaml
with:
  image: 'myuser/my-app'
# Outputs:
#   provider: dockerhub
#   account: myuser
#   registry: docker.io
#   repository: my-app
#   registry_type: dockerhub
```

### Docker Hub Official Images
```yaml
with:
  image: 'nginx'
# Outputs:
#   provider: dockerhub
#   account: library  # Official images use 'library' namespace
#   registry: docker.io
#   repository: nginx
#   registry_type: dockerhub
```

### Generic Private Registry
```yaml
with:
  image: 'registry.company.com/team/my-app'
# Outputs:
#   provider: generic
#   account: team
#   registry: registry.company.com
#   repository: my-app
#   registry_type: generic
```

## Advanced Use Cases

### Monorepo with Multiple Services

In a monorepo where different services use different registries:

```yaml
strategy:
  matrix:
    service:
      - name: payment-service
        image: 123456789.dkr.ecr.us-east-1.amazonaws.com/payment
      - name: user-service
        image: us-central1-docker.pkg.dev/my-project/services/users
      - name: notification-service
        image: ghcr.io/myorg/notifications

steps:
  - name: Parse registry for ${{ matrix.service.name }}
    id: parse_registry
    uses: KoalaOps/parse-image-registry@v1
    with:
      image: ${{ matrix.service.image }}
  
  # Authentication and build steps follow...
```

### Dynamic Environment-Based Registries

```yaml
- name: Determine registry based on environment
  id: get_image
  run: |
    if [ "${{ github.event.inputs.environment }}" == "production" ]; then
      echo "image=123456789.dkr.ecr.us-east-1.amazonaws.com/my-app" >> $GITHUB_OUTPUT
    else
      echo "image=ghcr.io/${{ github.repository_owner }}/my-app" >> $GITHUB_OUTPUT
    fi

- name: Parse registry
  id: parse_registry
  uses: KoalaOps/parse-image-registry@v1
  with:
    image: ${{ steps.get_image.outputs.image }}
```

## Environment Variables

The action exports the following environment variables for use in subsequent steps:

- `IMAGE_PROVIDER` - The detected cloud provider
- `IMAGE_ACCOUNT` - The account/project ID
- `IMAGE_REGION` - The region/location (if applicable)
- `IMAGE_REGISTRY` - The full registry URL
- `IMAGE_REPOSITORY` - The repository/image name
- `IMAGE_REGISTRY_TYPE` - The type of registry

Example usage:
```yaml
- name: Parse image registry
  uses: KoalaOps/parse-image-registry@v1
  with:
    image: '123456789.dkr.ecr.us-east-1.amazonaws.com/my-app'

- name: Use environment variables
  run: |
    echo "Pushing to $IMAGE_REGISTRY in region $IMAGE_REGION"
    docker tag my-app:latest $IMAGE_REGISTRY/$IMAGE_REPOSITORY:latest
```

## Troubleshooting

### Image URL Not Recognized

If the action fails to parse your image URL:

1. **Check the URL format** - Ensure it matches one of the supported patterns
2. **Remove protocols** - The action automatically strips `https://` and `http://`
3. **For generic registries** - Ensure the URL contains a domain (e.g., `registry.company.com/image`)

### Missing Region Information

Some registries don't encode region information in their URLs:
- **Azure Container Registry** - Region is not part of the URL
- **Docker Hub** - No region concept
- **GitHub Container Registry** - Global service

For these cases, the `region` output will be empty.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

For issues, questions, or suggestions, please open an issue in the [GitHub repository](https://github.com/KoalaOps/parse-image-registry).

## License

MIT