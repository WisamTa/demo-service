# CI/CD Workflows Comparison - Demo Service

## Overview
The demo-service repository has three distinct GitHub Actions workflows designed for different scenarios in the development lifecycle.

---

## 1. **ci.yml** - Main Branch Pipeline
**File:** `.github/workflows/ci.yml`

### Trigger Events
```yaml
on:
  push:
    branches: [ "main", "develop" ]
  pull_request:
    branches: [ "main" ]
```

### Purpose
- Production-ready pipeline for main and develop branches
- Includes **full infrastructure deployment** via Terraform
- Runs Terraform **apply** (actual infrastructure changes)

### GCP Configuration
- **Project:** `curamet-onboarding`
- **Region:** `europe-west1`
- **No Docker Registry:** Only uses Terraform for deployment

### Key Characteristics

| Feature | Details |
|---------|---------|
| **Scope** | Single job: `build-and-deploy` |
| **Node.js Setup** | Version 18 with npm cache |
| **Build Steps** | Install, Lint, Build |
| **Testing** | No automated tests |
| **GCP Auth** | Service account key authentication |
| **Docker** | Configured but not used for image push |
| **Terraform** | ✅ Full deployment (apply) on main |
| **Infrastructure Changes** | ✅ YES - Applies on main push |
| **PR Deployment** | ❌ Plan only on PR |

### Jobs
1. **build-and-deploy** (Single Job)
   - Builds application
   - Authenticates to GCP
   - Configures Terraform
   - Runs `terraform plan`
   - **Runs `terraform apply` ONLY on main branch push**

### Limitations
- No parallel job execution
- No artifact uploads
- No security scanning
- No code quality checks
- No Docker image versioning

---

## 2. **ci-cd-non-main.yml** - Feature Branches Pipeline
**File:** `.github/workflows/ci-cd-non-main.yml`

### Trigger Events
```yaml
on:
  push:
    branches: [ "develop", "staging", "test/**", "feature/**" ]
  pull_request:
    branches: [ "develop" ]
```

### Purpose
- Pipeline for feature development and testing branches
- Builds and pushes Docker images to Artifact Registry
- Runs Terraform **plan only** (no infrastructure changes)
- Supports parallel job execution

### GCP Configuration
- **Project:** `curamet-onboarding`
- **Region:** `europe-west1`
- **Registry:** `europe-docker.pkg.dev`
- **Image:** `curamet-onboarding/demo-service/demo-app`

### Key Characteristics

| Feature | Details |
|---------|---------|
| **Scope** | 3 parallel jobs |
| **Node.js Setup** | Version 18 with npm cache |
| **Build Steps** | Install, Lint, Build, Test |
| **Testing** | ✅ Included and uploaded as artifacts |
| **GCP Auth** | Service account key authentication |
| **Docker** | ✅ Builds and pushes images |
| **Image Tags** | Branch name, commit SHA, latest-branch |
| **Terraform** | Plan only (dry-run) |
| **Infrastructure Changes** | ❌ NO - Plan only |
| **Artifact Registry** | ✅ Pushes to Artifact Registry |

### Jobs (Parallel Execution)
1. **build-and-test**
   - Tests execution
   - Artifact upload (dist/)

2. **build-and-push-image**
   - Depends on: `build-and-test`
   - Builds Docker image
   - Pushes to Artifact Registry with 3 tags
   - GCP authentication

3. **terraform-plan**
   - Depends on: `build-and-push-image`
   - Terraform validation
   - Plan only (no apply)
   - Formats check

### Advantages
- Parallel execution improves speed
- Docker image versioning with multiple tags
- Artifact preservation for 5 days
- Terraform validation without applying changes
- Safe for feature development

---

## 3. **ci-cd-pull-request.yml** - Pull Request Pipeline
**File:** `.github/workflows/ci-cd-pull-request.yml`

### Trigger Events
```yaml
on:
  pull_request:
    branches: [ "main", "develop" ]
```

### Purpose
- Comprehensive code quality and security verification for PRs
- Separate GCP project for isolation
- Enhanced code review workflow
- Automated PR comments with results

### GCP Configuration
- **Project:** `zeta-pivot-272421` (Sandbox - curamet-sandbox)
- **Region:** `europe-west1`
- **Registry:** `europe-docker.pkg.dev`
- **Image:** `zeta-pivot-272421/demo-service/demo-app`

### Key Characteristics

| Feature | Details |
|---------|---------|
| **Scope** | 5 parallel jobs + summary |
| **Node.js Setup** | Version 18 with npm cache |
| **Build Steps** | Install, Lint, Build, Test |
| **Testing** | ✅ Included with coverage reporting |
| **GCP Auth** | Service account key authentication |
| **Docker** | Not used in this pipeline |
| **Code Quality** | ✅ Audit, coverage analysis |
| **Security Scan** | ✅ Dependency vulnerability scanning |
| **Terraform** | Plan only with artifact preservation |
| **Infrastructure Changes** | ❌ NO - Plan only |
| **PR Comments** | ✅ Automated status updates |
| **Coverage Reports** | ✅ Uploaded as artifacts |

### Jobs (Parallel Execution + Dependencies)
1. **build-and-test**
   - Build, lint, tests
   - Artifact upload (dist/)

2. **code-quality** (Parallel)
   - Security audit
   - Coverage analysis
   - Coverage report upload

3. **security-scan** (Parallel)
   - Dependency vulnerability scanning
   - OWASP Dependency Check

4. **terraform-plan** (Depends on: build-and-test, code-quality)
   - Terraform validation
   - Plan artifact upload
   - **Comments on PR with Terraform plan**

5. **summary** (Final)
   - Posts final summary to PR
   - Shows all check statuses

### Special Features
- **PR Comments:** Automated feedback with Terraform plan details
- **Coverage Reports:** Full test coverage metrics
- **Vulnerability Scanning:** Dependency Check integration
- **Isolation:** Separate GCP project for PR testing
- **Always Runs:** Summary job runs even if previous jobs fail

---

## Comparison Matrix

| Feature | ci.yml | ci-cd-non-main.yml | ci-cd-pull-request.yml |
|---------|--------|-------------------|----------------------|
| **Trigger** | main, develop push | develop, staging, feature/* | PRs to main/develop |
| **GCP Project** | curamet-onboarding | curamet-onboarding | zeta-pivot-272421 |
| **Docker Push** | ❌ | ✅ Artifact Registry | ❌ |
| **Terraform Apply** | ✅ main only | ❌ plan only | ❌ plan only |
| **Test Execution** | ❌ | ✅ | ✅ |
| **Code Quality** | ❌ | ❌ | ✅ audit + coverage |
| **Security Scan** | ❌ | ❌ | ✅ vulnerability scan |
| **Parallel Jobs** | ❌ 1 job | ✅ 3 jobs | ✅ 5 jobs |
| **PR Comments** | ❌ | ❌ | ✅ automatic feedback |
| **Artifacts** | ❌ | ✅ dist/, tfplan | ✅ dist/, coverage, tfplan |
| **Permissions** | read + id-token | read + id-token | read + id-token + PR write |

---

## Recommended Usage Flow

```
Feature Development
  ↓
Push to feature/* branch
  ├─→ Runs: ci-cd-non-main.yml
  │   - Build, test, push Docker image
  │   - Terraform plan
  ↓
Create Pull Request
  ├─→ Runs: ci-cd-pull-request.yml
  │   - Full code quality analysis
  │   - Security scanning
  │   - Automated PR comments
  ↓
Merge to develop
  ├─→ Runs: ci.yml (on develop)
  │   - Build & deploy (plan only on develop)
  ↓
Merge to main
  ├─→ Runs: ci.yml (on main)
  │   - Build & deploy with TERRAFORM APPLY
  │   - Production infrastructure changes
```

---

## Key Differences Summary

### 1. **Execution Scope**
- **ci.yml:** Single consolidated job (monolithic)
- **ci-cd-non-main.yml:** 3 parallel jobs (faster)
- **ci-cd-pull-request.yml:** 5 parallel jobs + summary (comprehensive)

### 2. **Infrastructure Management**
- **ci.yml:** APPLIES changes on main (production)
- **ci-cd-non-main.yml:** PLANS only (safe)
- **ci-cd-pull-request.yml:** PLANS only in sandbox project (isolated)

### 3. **Code Quality**
- **ci.yml:** Minimal (build + linting)
- **ci-cd-non-main.yml:** Basic (build + test)
- **ci-cd-pull-request.yml:** Comprehensive (audit + coverage + vulnerability scan)

### 4. **Docker/Artifact Registry**
- **ci.yml:** Not used
- **ci-cd-non-main.yml:** Pushes images with branch/SHA tags
- **ci-cd-pull-request.yml:** Not used

### 5. **GCP Isolation**
- **ci.yml:** Production project
- **ci-cd-non-main.yml:** Production project
- **ci-cd-pull-request.yml:** Sandbox project (zeta-pivot-272421)

### 6. **Feedback Mechanisms**
- **ci.yml:** Logs only
- **ci-cd-non-main.yml:** Logs only
- **ci-cd-pull-request.yml:** Automated PR comments + artifacts

---

## Best Practices

✅ **DO:**
- Use feature branches to test code with ci-cd-non-main.yml
- Create PRs to get comprehensive feedback from ci-cd-pull-request.yml
- Use main branch for production deployments with ci.yml (terraform apply)
- Keep sandbox GCP project separate for PR testing

❌ **DON'T:**
- Push directly to main without PR review
- Skip the ci-cd-pull-request.yml feedback
- Use main branch for testing (use develop instead)
- Share GCP service accounts between workflows

---

## Summary

| Workflow | Stage | Primary Purpose | Risk Level |
|----------|-------|-----------------|-----------|
| **ci.yml** | Production | Deploy infrastructure to main GCP | 🔴 High (applies changes) |
| **ci-cd-non-main.yml** | Development | Build & push images for testing | 🟡 Medium (dry-run only) |
| **ci-cd-pull-request.yml** | Review | Quality & security checks in sandbox | 🟢 Low (isolated) |

