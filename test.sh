#!/bin/bash
# Local test script for parse-image-registry action
# Run this to test the parsing logic locally without GitHub Actions

# Don't exit on error immediately, we handle errors manually
set +e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local image="$2"
    local expected_provider="$3"
    local expected_account="$4"
    local expected_region="$5"
    local expected_registry="$6"
    local expected_repository="$7"
    local expected_type="$8"
    
    echo -n "Testing $test_name... "
    
    # Source the parsing logic (extract from action.yml)
    IMAGE="$image"
    
    # Initialize variables
    PROVIDER=""
    ACCOUNT=""
    REGION=""
    REGISTRY=""
    REPOSITORY=""
    REGISTRY_TYPE=""
    
    # Remove protocol if present
    IMAGE="${IMAGE#https://}"
    IMAGE="${IMAGE#http://}"
    
    # AWS ECR Detection
    if [[ "$IMAGE" =~ ^([0-9]{12})\.dkr\.ecr\.([a-z0-9-]+)\.amazonaws\.com/(.+)$ ]]; then
        PROVIDER="aws"
        ACCOUNT="${BASH_REMATCH[1]}"
        REGION="${BASH_REMATCH[2]}"
        REPOSITORY="${BASH_REMATCH[3]}"
        REGISTRY="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"
        REGISTRY_TYPE="ecr"
    
    # AWS ECR Public Detection
    elif [[ "$IMAGE" =~ ^public\.ecr\.aws/([^/]+)/(.+)$ ]]; then
        PROVIDER="aws"
        ACCOUNT="${BASH_REMATCH[1]}"
        REGION="us-east-1"
        REPOSITORY="${BASH_REMATCH[2]}"
        REGISTRY="public.ecr.aws/${ACCOUNT}"
        REGISTRY_TYPE="ecr-public"
    
    # GCP Artifact Registry Detection
    elif [[ "$IMAGE" =~ ^([a-z0-9-]+)-docker\.pkg\.dev/([^/]+)/([^/]+)/(.+)$ ]]; then
        PROVIDER="gcp"
        REGION="${BASH_REMATCH[1]}"
        ACCOUNT="${BASH_REMATCH[2]}"
        GCP_REGISTRY="${BASH_REMATCH[3]}"
        REPOSITORY="${BASH_REMATCH[4]}"
        REGISTRY="${REGION}-docker.pkg.dev/${ACCOUNT}/${GCP_REGISTRY}"
        REGISTRY_TYPE="artifact-registry"
    
    # GCP Container Registry Detection (legacy)
    elif [[ "$IMAGE" =~ ^(([a-z]+\.)?)gcr\.io/([^/]+)/(.+)$ ]]; then
        PROVIDER="gcp"
        REGION="${BASH_REMATCH[2]%%.}"
        ACCOUNT="${BASH_REMATCH[3]}"
        REPOSITORY="${BASH_REMATCH[4]}"
        if [ -z "$REGION" ]; then
            REGISTRY="gcr.io/${ACCOUNT}"
            REGION="us"
        else
            REGISTRY="${REGION}.gcr.io/${ACCOUNT}"
        fi
        REGISTRY_TYPE="gcr"
    
    # Azure Container Registry Detection
    elif [[ "$IMAGE" =~ ^([^.]+)\.azurecr\.io/(.+)$ ]]; then
        PROVIDER="azure"
        ACCOUNT="${BASH_REMATCH[1]}"
        REPOSITORY="${BASH_REMATCH[2]}"
        REGISTRY="${ACCOUNT}.azurecr.io"
        REGISTRY_TYPE="acr"
    
    # GitHub Container Registry Detection
    elif [[ "$IMAGE" =~ ^ghcr\.io/([^/]+)/(.+)$ ]]; then
        PROVIDER="github"
        ACCOUNT="${BASH_REMATCH[1]}"
        REPOSITORY="${BASH_REMATCH[2]}"
        REGISTRY="ghcr.io"
        REGISTRY_TYPE="ghcr"
    
    # Docker Hub Detection - Full format
    elif [[ "$IMAGE" =~ ^docker\.io/([^/]+)/(.+)$ ]]; then
        PROVIDER="dockerhub"
        ACCOUNT="${BASH_REMATCH[1]}"
        REPOSITORY="${BASH_REMATCH[2]}"
        REGISTRY="docker.io"
        REGISTRY_TYPE="dockerhub"
    
    # Generic registry with domain (including port)
    elif [[ "$IMAGE" =~ ^([^/]+\.[^/]+)/(.+)$ ]] || [[ "$IMAGE" =~ ^([^/]+:[0-9]+)/(.+)$ ]]; then
        PROVIDER="generic"
        REGISTRY="${BASH_REMATCH[1]}"
        REPOSITORY="${BASH_REMATCH[2]}"
        REGISTRY_TYPE="generic"
        
        if [[ "$REPOSITORY" =~ ^([^/]+)/(.+)$ ]]; then
            ACCOUNT="${BASH_REMATCH[1]}"
            REPOSITORY="${BASH_REMATCH[2]}"
        fi
    
    # Docker Hub short format (no domain)
    elif [[ "$IMAGE" =~ ^([^/\.]+)/([^/]+)$ ]]; then
        PROVIDER="dockerhub"
        ACCOUNT="${BASH_REMATCH[1]}"
        REPOSITORY="${BASH_REMATCH[2]}"
        REGISTRY="docker.io"
        REGISTRY_TYPE="dockerhub"
    
    
    # Fallback for simple image names (assume Docker Hub)
    elif [[ "$IMAGE" =~ ^[^/]+$ ]]; then
        PROVIDER="dockerhub"
        ACCOUNT="library"
        REPOSITORY="$IMAGE"
        REGISTRY="docker.io"
        REGISTRY_TYPE="dockerhub"
    fi
    
    # Check results
    local all_pass=true
    
    if [[ "$PROVIDER" != "$expected_provider" ]]; then
        echo -e "${RED}✗${NC}"
        echo "  Provider: expected '$expected_provider', got '$PROVIDER'"
        all_pass=false
    fi
    
    if [[ "$ACCOUNT" != "$expected_account" ]] && [[ -n "$expected_account" ]]; then
        echo -e "${RED}✗${NC}"
        echo "  Account: expected '$expected_account', got '$ACCOUNT'"
        all_pass=false
    fi
    
    if [[ "$REGION" != "$expected_region" ]] && [[ -n "$expected_region" ]]; then
        echo -e "${RED}✗${NC}"
        echo "  Region: expected '$expected_region', got '$REGION'"
        all_pass=false
    fi
    
    if [[ "$REGISTRY" != "$expected_registry" ]] && [[ -n "$expected_registry" ]]; then
        echo -e "${RED}✗${NC}"
        echo "  Registry: expected '$expected_registry', got '$REGISTRY'"
        all_pass=false
    fi
    
    if [[ "$REPOSITORY" != "$expected_repository" ]] && [[ -n "$expected_repository" ]]; then
        echo -e "${RED}✗${NC}"
        echo "  Repository: expected '$expected_repository', got '$REPOSITORY'"
        all_pass=false
    fi
    
    if [[ "$REGISTRY_TYPE" != "$expected_type" ]] && [[ -n "$expected_type" ]]; then
        echo -e "${RED}✗${NC}"
        echo "  Registry Type: expected '$expected_type', got '$REGISTRY_TYPE'"
        all_pass=false
    fi
    
    if $all_pass; then
        echo -e "${GREEN}✓${NC}"
        ((TESTS_PASSED++))
    else
        ((TESTS_FAILED++))
    fi
}

echo "Running parse-image-registry tests..."
echo "===================================="
echo

# AWS ECR Tests
echo -e "${YELLOW}AWS ECR Tests:${NC}"
run_test "AWS ECR standard" \
    "123456789012.dkr.ecr.us-east-1.amazonaws.com/my-service" \
    "aws" "123456789012" "us-east-1" \
    "123456789012.dkr.ecr.us-east-1.amazonaws.com" \
    "my-service" "ecr"

run_test "AWS ECR with nested path" \
    "987654321098.dkr.ecr.eu-west-2.amazonaws.com/team/project/service" \
    "aws" "987654321098" "eu-west-2" \
    "987654321098.dkr.ecr.eu-west-2.amazonaws.com" \
    "team/project/service" "ecr"

run_test "AWS ECR Public" \
    "public.ecr.aws/myalias/my-app" \
    "aws" "myalias" "us-east-1" \
    "public.ecr.aws/myalias" \
    "my-app" "ecr-public"

echo

# GCP Tests
echo -e "${YELLOW}GCP Tests:${NC}"
run_test "GCP Artifact Registry (Regional)" \
    "us-central1-docker.pkg.dev/my-project/my-registry/my-service" \
    "gcp" "my-project" "us-central1" \
    "us-central1-docker.pkg.dev/my-project/my-registry" \
    "my-service" "artifact-registry"

run_test "GCP Artifact Registry (Multi-regional)" \
    "us-docker.pkg.dev/my-project/my-registry/my-service" \
    "gcp" "my-project" "us" \
    "us-docker.pkg.dev/my-project/my-registry" \
    "my-service" "artifact-registry"

run_test "GCP Container Registry (gcr.io)" \
    "gcr.io/my-project/my-app" \
    "gcp" "my-project" "us" \
    "gcr.io/my-project" \
    "my-app" "gcr"

run_test "GCP Regional GCR (EU)" \
    "eu.gcr.io/my-project/my-service" \
    "gcp" "my-project" "eu" \
    "eu.gcr.io/my-project" \
    "my-service" "gcr"

run_test "GCP Regional GCR (Asia)" \
    "asia.gcr.io/my-project/my-service" \
    "gcp" "my-project" "asia" \
    "asia.gcr.io/my-project" \
    "my-service" "gcr"

echo

# Azure Tests
echo -e "${YELLOW}Azure Tests:${NC}"
run_test "Azure ACR" \
    "myregistry.azurecr.io/my-app" \
    "azure" "myregistry" "" \
    "myregistry.azurecr.io" \
    "my-app" "acr"

run_test "Azure ACR with nested path" \
    "contoso.azurecr.io/products/web/frontend" \
    "azure" "contoso" "" \
    "contoso.azurecr.io" \
    "products/web/frontend" "acr"

echo

# GitHub Tests
echo -e "${YELLOW}GitHub Tests:${NC}"
run_test "GitHub Container Registry" \
    "ghcr.io/myorg/my-service" \
    "github" "myorg" "" \
    "ghcr.io" \
    "my-service" "ghcr"

run_test "GHCR with nested path" \
    "ghcr.io/myorg/team/project/service" \
    "github" "myorg" "" \
    "ghcr.io" \
    "team/project/service" "ghcr"

echo

# Docker Hub Tests
echo -e "${YELLOW}Docker Hub Tests:${NC}"
run_test "Docker Hub short format" \
    "myuser/my-app" \
    "dockerhub" "myuser" "" \
    "docker.io" \
    "my-app" "dockerhub"

run_test "Docker Hub full format" \
    "docker.io/myuser/my-service" \
    "dockerhub" "myuser" "" \
    "docker.io" \
    "my-service" "dockerhub"

run_test "Docker Hub official image" \
    "nginx" \
    "dockerhub" "library" "" \
    "docker.io" \
    "nginx" "dockerhub"

echo

# Generic Registry Tests
echo -e "${YELLOW}Generic Registry Tests:${NC}"
run_test "Generic registry" \
    "registry.company.com/team/my-app" \
    "generic" "team" "" \
    "registry.company.com" \
    "my-app" "generic"

run_test "Generic with port" \
    "localhost:5000/my-service" \
    "generic" "" "" \
    "localhost:5000" \
    "my-service" "generic"

echo

# Edge Cases
echo -e "${YELLOW}Edge Cases:${NC}"
run_test "URL with https://" \
    "https://ghcr.io/owner/repo" \
    "github" "owner" "" \
    "ghcr.io" \
    "repo" "ghcr"

echo
echo "===================================="
echo -e "Results: ${GREEN}$TESTS_PASSED passed${NC}, ${RED}$TESTS_FAILED failed${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi