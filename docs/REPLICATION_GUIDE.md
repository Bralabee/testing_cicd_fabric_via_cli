# Replication Guide — Microsoft Fabric CI/CD from Scratch

> **Version**: 1.0.0 · **Last Updated**: 15 February 2026
>
> Step-by-step guide to set up a fully automated Microsoft Fabric CI/CD lifecycle
> using the `usf_fabric_cli_cicd` CLI and this consumer repository as a template.
> Covers prerequisite setup, configuration, deployment, testing, and customisation.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
   - 2.1 [Azure Entra ID (Service Principal)](#21-azure-entra-id-service-principal)
   - 2.2 [Microsoft Fabric Capacity](#22-microsoft-fabric-capacity)
   - 2.3 [GitHub Account & PAT](#23-github-account--pat)
3. [Repository Setup](#3-repository-setup)
   - 3.1 [Fork or Copy the Repos](#31-fork-or-copy-the-repos)
   - 3.2 [Understand the Two-Repo Model](#32-understand-the-two-repo-model)
4. [Configure Secrets & Variables](#4-configure-secrets--variables)
   - 4.1 [GitHub Secrets (Required)](#41-github-secrets-required)
   - 4.2 [GitHub Repository Variables (Optional)](#42-github-repository-variables-optional)
5. [Customise the Configuration](#5-customise-the-configuration)
   - 5.1 [Choose Your Project Prefix](#51-choose-your-project-prefix)
   - 5.2 [Edit Config Files (Optional)](#52-edit-config-files-optional)
6. [Phase 1 — Initial Deployment](#6-phase-1--initial-deployment)
7. [Phase 2 — Feature Branch Lifecycle](#7-phase-2--feature-branch-lifecycle)
8. [Phase 3 — Promotion (Dev → Test → Prod)](#8-phase-3--promotion-dev--test--prod)
9. [Verification Checklist](#9-verification-checklist)
10. [Common Bottlenecks & Troubleshooting](#10-common-bottlenecks--troubleshooting)
11. [Keeping the CLI Updated](#11-keeping-the-cli-updated)
12. [Customising for Your Own Project](#12-customising-for-your-own-project)
13. [Architecture Reference](#13-architecture-reference)

---

## 1. Overview

This guide walks you through replicating the complete Microsoft Fabric CI/CD lifecycle for your own organisation. By the end, you will have:

- **3 Fabric workspaces** (Dev, Test, Prod) connected via a Deployment Pipeline
- **Automated feature workspace isolation** — push a `feature/*` branch, get a workspace; merge the PR, workspace is destroyed
- **Automated promotion** — code merged to `main` auto-promotes Dev → Test; manual trigger promotes Test → Prod
- **Git-synced development** — the Dev workspace tracks the `main` branch automatically

**Time estimate**: 45–90 minutes (first time), depending on Azure/Fabric familiarity.

### How It Works

```
┌─────────────────────────────────────────────────────────────────────┐
│                     YOUR CONSUMER REPO (GitHub)                     │
│                                                                     │
│  config/projects/demo/                                              │
│    ├── base_workspace.yaml       ← Dev + Pipeline + Test + Prod    │
│    └── feature_workspace_demo.yaml  ← Feature workspace template   │
│                                                                     │
│  .github/workflows/                                                 │
│    ├── ci.yml                    ← CI validation on push/PR        │
│    ├── setup-base-workspaces.yml ← Run once (manual)               │
│    ├── feature-workspace-create.yml  ← On push to feature/*        │
│    ├── feature-workspace-cleanup.yml ← On PR merge to main         │
│    ├── promote-dev-to-test.yml   ← Auto on push to main            │
│    └── promote-test-to-prod.yml  ← Manual with "PROMOTE" gate     │
├─────────────────────────────────────────────────────────────────────┤
│                           ↓ installs at runtime ↓                   │
│                  CLI REPO (usf_fabric_cli_cicd)                     │
│         Provides: fabric-cicd deploy / destroy / promote            │
└─────────────────────────────────────────────────────────────────────┘
                           ↓ talks to ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    MICROSOFT FABRIC (Cloud)                         │
│                                                                     │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐                      │
│  │  Dev WS   │───▶│  Test WS  │───▶│  Prod WS  │                   │
│  │ (Git sync)│    │           │    │           │                    │
│  └──────────┘    └──────────┘    └──────────┘                      │
│        ▲          Deployment Pipeline                               │
│        │                                                            │
│  ┌──────────┐                                                       │
│  │Feature WS │  ← temporary, per-branch                            │
│  └──────────┘                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Prerequisites

### 2.1 Azure Entra ID (Service Principal)

> **⚠️ Bottleneck alert**: This is the #1 setup blocker. Most issues stem from
> insufficient Service Principal permissions.

You need a Service Principal (SP) with credentials for automated deployments.

**Create the SP:**

```bash
# Install Azure CLI if needed: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli
az login

# Create the Service Principal
az ad sp create-for-rbac \
  --name "fabric-cicd-sp" \
  --role Contributor \
  --scopes /subscriptions/<YOUR_SUBSCRIPTION_ID>
```

This outputs:
```json
{
  "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",     ← AZURE_CLIENT_ID
  "password": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", ← AZURE_CLIENT_SECRET
  "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"      ← AZURE_TENANT_ID
}
```

**Save these values** — you will need them in Step 4.

**Grant Fabric permissions to the SP:**

1. Go to **Microsoft Fabric Admin Portal** → **Tenant settings**
2. Under **Developer settings**, enable:
   - ✅ *Service principals can use Fabric APIs*
   - ✅ *Service principals can create and use profiles*
3. Add your SP (by App ID or Security Group) to the allowed list
4. Under **Workspace settings** → enable *Service principals can access workspaces*

> **💡 Tip**: If your Fabric admin has locked down API access to a specific Security
> Group, add your SP's App ID to that group in Entra ID.

**Get the SP's Object ID** (needed for `DEV_ADMIN_OBJECT_ID`):

```bash
az ad sp show --id <YOUR_APP_ID> --query id -o tsv
```

### 2.2 Microsoft Fabric Capacity

You need an active Fabric capacity (F2 or higher) to create workspaces.

**Check your capacity:**

1. Go to **Fabric Admin Portal** → **Capacity settings**
2. Note the **Capacity ID** (a GUID) — this becomes `FABRIC_CAPACITY_ID`
3. Ensure your SP has **Capacity Contributor** role on the capacity:
   - Admin Portal → Capacity → Permissions → Add your SP

> **⚠️ F2 (trial) limits**: F2 capacities have low workspace and compute limits.
> If you hit "capacity exhausted" errors, clean up unused workspaces or upgrade.

**If you don't have a capacity:**

- **Trial**: [Start a Fabric trial](https://learn.microsoft.com/en-us/fabric/get-started/fabric-trial) (F2, 60 days free)
- **Pay-as-you-go**: Create an F2 capacity in Azure Portal → Microsoft Fabric

### 2.3 GitHub Account & PAT

**Create a Personal Access Token (PAT):**

1. Go to **GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens**
2. Create a token with these permissions:
   - ✅ **Contents**: Read and write (to clone the CLI repo)
   - ✅ **Metadata**: Read-only
3. Set the scope to the organisation/repos that host your CLI repo

> **💡 Why a PAT?** Fabric's Git integration uses this token to connect workspaces
> to your GitHub repository. The workflows also use it to clone the CLI package.

**Save the PAT** — this becomes `FABRIC_GITHUB_TOKEN` in Step 4.

---

## 3. Repository Setup

### 3.1 Fork or Copy the Repos

You need **two repositories**:

| Repo | Purpose | What to do |
|------|---------|------------|
| **CLI repo** (product) | Contains the `fabric-cicd` CLI tool | Fork `usf_fabric_cli_cicd` into your GitHub org, or use as-is if you have read access |
| **Consumer repo** (this one) | Contains config + workflows | Fork `fabric_cicd_test_repo` into your GitHub org, then customise |

**Fork the consumer repo:**

```bash
# Option A: Fork via GitHub UI (recommended)
# Go to the repo → Fork → Choose your org

# Option B: Create a fresh copy
mkdir my-fabric-cicd && cd my-fabric-cicd
git init
# Copy the contents of fabric_cicd_test_repo into this directory
git add -A && git commit -m "chore: initial setup from template"
git remote add origin https://github.com/<YOUR_ORG>/<YOUR_REPO>.git
git push -u origin main
```

### 3.2 Understand the Two-Repo Model

```
┌──────────────────────────────────┐    ┌──────────────────────────────┐
│  CLI REPO (product)              │    │  CONSUMER REPO (yours)       │
│                                  │    │                              │
│  • fabric-cicd CLI binary        │◄───│  • Workflows install CLI     │
│  • deploy / destroy / promote    │    │    at runtime via pip        │
│  • Shared across all projects    │    │  • Config YAML per project   │
│                                  │    │  • GitHub Actions workflows  │
└──────────────────────────────────┘    └──────────────────────────────┘
```

**Why two repos?**
- The CLI is a shared tool — many consumer repos can use the same CLI version
- Your configs and workflows are project-specific
- Separating concerns makes upgrades clean (update CLI version, consumer stays stable)

---

## 4. Configure Secrets & Variables

Go to your **consumer repo** on GitHub → **Settings** → **Secrets and variables** → **Actions**.

### 4.1 GitHub Secrets (Required)

These are sensitive values that must never appear in code or logs.

| Secret Name | Value | Where to get it |
|-------------|-------|------------------|
| `AZURE_TENANT_ID` | Your Entra ID tenant GUID | Step 2.1 (`az ad sp create-for-rbac` output) |
| `AZURE_CLIENT_ID` | Service Principal application ID | Step 2.1 |
| `AZURE_CLIENT_SECRET` | Service Principal password | Step 2.1 |
| `FABRIC_GITHUB_TOKEN` | GitHub PAT with repo access | Step 2.3 |
| `FABRIC_CAPACITY_ID` | Fabric capacity GUID | Step 2.2 |
| `DEV_ADMIN_OBJECT_ID` | SP's Object ID (for workspace admin) | Step 2.1 (`az ad sp show`) |

**How to add secrets:**

1. Go to repo **Settings → Secrets and variables → Actions**
2. Click **New repository secret**
3. Enter the name (e.g., `AZURE_TENANT_ID`) and the value
4. Repeat for all 6 secrets

### 4.2 GitHub Repository Variables (Optional)

These customise the deployment without touching code. All have sensible defaults.

Go to **Settings → Secrets and variables → Actions → Variables tab**.

| Variable | Default | Description |
|----------|---------|-------------|
| `PROJECT_PREFIX` | `fabric-cicd-demo` | Prefix for all workspace names (e.g., `myproject` → workspaces named `myproject-dev`, `myproject-test`, `myproject-prod`) |
| `CLI_REPO_URL` | `github.com/your-org/your-cli-repo` | URL to your CLI repo (without `https://`) |
| `CLI_REPO_REF` | `v1.7.6` | Tag (or branch) of the CLI repo to install |
| `FABRIC_CLI_VERSION` | `1.3.1` | Version of the Microsoft `ms-fabric-cli` package |
| `FEATURE_WORKSPACE_CONFIG` | *(auto-detected)* | Path to feature workspace config, e.g., `config/projects/demo/feature_workspace_demo.yaml` |

> **💡 Quick start**: If you only change one thing, set `PROJECT_PREFIX` to something
> meaningful for your project (e.g., `sales-analytics`, `hr-reporting`). This names
> all your workspaces accordingly.

**How to add variables:**

1. Go to repo **Settings → Secrets and variables → Actions → Variables tab**
2. Click **New repository variable**
3. Enter the name (e.g., `PROJECT_PREFIX`) and value (e.g., `my-project`)

---

## 5. Customise the Configuration

### 5.1 Choose Your Project Prefix

The `PROJECT_PREFIX` variable determines workspace naming:

| PROJECT_PREFIX | Dev Workspace | Test Workspace | Prod Workspace | Pipeline Name |
|----------------|---------------|----------------|----------------|---------------|
| `fabric-cicd-demo` | `fabric-cicd-demo-dev` | `fabric-cicd-demo-test` | `fabric-cicd-demo-prod` | `fabric-cicd-demo-pipeline` |
| `sales-analytics` | `sales-analytics-dev` | `sales-analytics-test` | `sales-analytics-prod` | `sales-analytics-pipeline` |
| `hr-reporting` | `hr-reporting-dev` | `hr-reporting-test` | `hr-reporting-prod` | `hr-reporting-pipeline` |

You can set this as a **repo variable** (Step 4.2) or accept the default.

### 5.2 Edit Config Files (Optional)

The configs in `config/projects/demo/` work out of the box. If you need to customise:

**`base_workspace.yaml`** — the main Dev workspace + pipeline:

```yaml
# All names use ${PROJECT_PREFIX} — set via repo variable, not here
workspace:
  name: ${PROJECT_PREFIX}-dev
  display_name: ${PROJECT_PREFIX} - Development
  capacity_id: ${FABRIC_CAPACITY_ID}
  git_repo: ${GIT_REPO_URL}
  git_branch: main

# Add more resources as needed:
lakehouses:
  - name: lh_bronze
    folder: Bronze
  - name: lh_silver        # ← Add your own
    folder: Silver

notebooks:
  - name: demo_notebook
    folder: Bronze
  - name: transform_data   # ← Add your own
    folder: Silver
```

**`feature_workspace_demo.yaml`** — the feature branch workspace template:

```yaml
workspace:
  name: ${PROJECT_PREFIX}
  capacity_id: ${FABRIC_CAPACITY_ID}
  git_repo: ${GIT_REPO_URL}
  git_branch: main

# Feature workspaces inherit the same structure
# The CLI appends the branch name to the workspace name automatically
```

---

## 6. Phase 1 — Initial Deployment

This creates your base workspaces and the deployment pipeline. **Run once.**

### Step 1: Trigger the Setup Workflow

1. Go to your consumer repo on GitHub
2. Click **Actions** → **Setup Base Workspaces** (left sidebar)
3. Click **Run workflow** → select `dev` → **Run workflow**

### Step 2: Monitor the Run

- Watch the workflow logs in the Actions tab
- **Expected duration**: 2–5 minutes
- The workflow will:
  1. Install the CLI from your CLI repo
  2. Deploy the Dev workspace with Git sync to `main`
  3. Create the Deployment Pipeline
  4. Create Test and Prod workspaces and assign them to pipeline stages

### Step 3: Verify in Fabric Portal

1. Go to [app.fabric.microsoft.com](https://app.fabric.microsoft.com)
2. You should see three new workspaces:
   - `<prefix>-dev` (connected to your GitHub `main` branch)
   - `<prefix>-test`
   - `<prefix>-prod`
3. Go to **Deployment Pipelines** → you should see `<prefix>-pipeline` with all three stages assigned

> **⚠️ If the workflow fails**: Jump to [Section 10 — Troubleshooting](#10-common-bottlenecks--troubleshooting).

---

## 7. Phase 2 — Feature Branch Lifecycle

Test the full feature isolation cycle.

### Step 1: Create a Feature Branch

```bash
# In your consumer repo
git checkout -b feature/test-isolation
echo "# Test" >> test.md
git add test.md
git commit -m "feat: test feature workspace isolation"
git push origin feature/test-isolation
```

### Step 2: Watch Workspace Creation

1. Go to **Actions** → you'll see **Create Feature Workspace** running
2. **Expected duration**: 2–4 minutes
3. After completion, check Fabric portal — you'll see a new workspace:
   `<prefix>-feature-test-isolation`

### Step 3: Work in the Feature Workspace

- Open the feature workspace in Fabric portal
- It is Git-connected to your `feature/test-isolation` branch
- Make changes in Fabric → they sync back to the branch
- Make changes in Git → they sync to the feature workspace

### Step 4: Merge and Clean Up

```bash
# Create a PR on GitHub
# Merge the PR (this deletes the feature branch)
```

After merge:
1. **Cleanup workflow** runs automatically → destroys the feature workspace
2. **Promote Dev → Test** workflow runs automatically (because main was updated)

### Step 5: Verify

- Feature workspace is gone from Fabric portal
- Dev workspace has the changes (Git-synced from `main`)
- Test workspace has the promoted content

---

## 8. Phase 3 — Promotion (Dev → Test → Prod)

### Dev → Test (Automatic)

This happens automatically whenever code is pushed to `main`:
1. Fabric Git Sync updates the Dev workspace (30–120 seconds)
2. The promote workflow waits 60 seconds for sync to complete
3. CLI calls `fabric-cicd promote` to push Dev content → Test

### Test → Prod (Manual)

1. Go to **Actions** → **Promote Test → Production**
2. Click **Run workflow**
3. Type `PROMOTE` (exact, case-sensitive) in the confirmation field
4. Optionally add a deployment note
5. Click **Run workflow**

The workflow promotes Test content to the Production workspace.

---

## 9. Verification Checklist

After completing all three phases, verify:

| Check | Expected Result | How to Verify |
|-------|-----------------|---------------|
| ✅ Dev workspace exists | `<prefix>-dev` in Fabric portal | Fabric Portal → Workspaces |
| ✅ Test workspace exists | `<prefix>-test` in Fabric portal | Fabric Portal → Workspaces |
| ✅ Prod workspace exists | `<prefix>-prod` in Fabric portal | Fabric Portal → Workspaces |
| ✅ Deployment Pipeline exists | `<prefix>-pipeline` with 3 stages | Fabric Portal → Deployment Pipelines |
| ✅ Dev is Git-synced | Connected to `main` branch | Dev workspace → Source control |
| ✅ Feature workspace created | Workspace appeared on branch push | Actions → Create Feature Workspace |
| ✅ Feature workspace destroyed | Workspace gone after PR merge | Actions → Cleanup Feature Workspace |
| ✅ Dev → Test promoted | Test has Dev content | Fabric Portal → Deployment Pipelines |
| ✅ Test → Prod promoted | Prod has Test content | Fabric Portal → Deployment Pipelines |

---

## 10. Common Bottlenecks & Troubleshooting

### ❌ "InsufficientPrivileges" or "Access is forbidden"

**Cause**: The Service Principal lacks permissions.

**Fix:**
1. Ensure SP has **Admin** role on the Fabric workspace (or the SP created the workspace)
2. In Fabric Admin Portal → Tenant settings:
   - Enable *Service principals can use Fabric APIs*
   - Add your SP to the security group if one is configured
3. Ensure SP has **Capacity Contributor** on the Fabric capacity

### ❌ "Capacity ID not found" or workspace creation fails

**Cause**: Invalid or inaccessible capacity.

**Fix:**
1. Verify `FABRIC_CAPACITY_ID` secret is correct (it's a GUID)
2. Confirm capacity is in **Active** state (not paused/deallocated)
3. Ensure SP has permissions on the capacity

### ❌ "Repository not found" during Git sync

**Cause**: The PAT lacks access to the consumer repo, or the URL is wrong.

**Fix:**
1. Verify `FABRIC_GITHUB_TOKEN` has **Contents: Read and write** permissions
2. Ensure the token is scoped to the correct organisation/repository
3. Check that `GIT_REPO_URL` is auto-populated correctly (this is set automatically by the workflow from `github.server_url` + `github.repository`)

### ❌ "pip install" fails for the CLI

**Cause**: Can't install the CLI package from your CLI repo.

**Fix:**
1. Verify `CLI_REPO_URL` variable points to the correct repo (without `https://`, e.g., `github.com/your-org/your-cli-repo`)
2. Ensure `FABRIC_GITHUB_TOKEN` has read access to the CLI repo
3. Check `CLI_REPO_REF` (branch) exists on the CLI repo

### ❌ Promote workflow resolves pipeline name as empty

**Cause**: `${PROJECT_PREFIX}` in the YAML config wasn't resolved to the environment variable.

**Fix:**
1. Ensure `PROJECT_PREFIX` is set as a GitHub Actions **environment variable** in the workflow (it should be — the workflows set it via `vars.PROJECT_PREFIX`)
2. The promote workflow uses Python's `re.sub` to resolve `${VAR}` patterns at runtime — this requires the env vars to be set in the workflow step

### ❌ Feature workspace not created (no workflow triggered)

**Cause**: Branch naming doesn't match the trigger.

**Fix:**
1. Branch must start with `feature/` (e.g., `feature/my-thing`)
2. Check the push went to the correct remote (`origin`)
3. Ensure GitHub Actions is enabled on the repo

### ❌ Cleanup doesn't run after PR merge

**Cause**: The PR must be **merged** (not just closed), and the source branch must start with `feature/`.

**Fix:**
1. Merge the PR (the green "Merge" button), don't just close it
2. If the branch was already deleted, use the manual workflow dispatch:
   - Actions → Cleanup Feature Workspace → Run workflow → enter the branch name (e.g., `feature/my-thing`)

### ⏳ Promotion fails intermittently

**Cause**: Fabric Git Sync hasn't completed before the promote step runs.

**Fix:**
The promote-dev-to-test workflow includes a 60-second wait by default. If your workspace is large, you may need more time. Edit the wait step in the workflow to increase the duration.

### 💡 General Debugging Steps

1. **Read the workflow logs**: Actions tab → click the failed run → expand the failed step
2. **Check secrets**: Settings → Secrets → verify all 6 are set and not expired
3. **Check variables**: Settings → Variables → verify `PROJECT_PREFIX` etc. if you set them
4. **Test locally**: Install the CLI locally and run deploy manually to isolate issues:
   ```bash
   # Install CLI
   pip install ms-fabric-cli==1.3.1
   pip install "git+https://<your-pat>@<your-cli-repo>.git@v1.7.6"

   # Set env vars
   export AZURE_TENANT_ID=...
   export AZURE_CLIENT_ID=...
   export AZURE_CLIENT_SECRET=...
   export FABRIC_CAPACITY_ID=...
   export PROJECT_PREFIX=my-test

   # Deploy
   fabric-cicd deploy config/projects/demo/base_workspace.yaml --env dev
   ```

---

## 11. Keeping the CLI Updated

The consumer repo installs the CLI from source via `git+https://` pinned to a **version tag**
(e.g. `v1.7.6`). This means the CLI version only changes when you explicitly update it.

### When to Update

After any meaningful change to the CLI repo (new feature, bug fix, config change),
you need to **tag the new version** in the CLI repo and **update the consumer workflows**.

### Step-by-Step Update Routine

```bash
# ── In the CLI repo ──

# 1. Make your code changes, commit, push
git add -A && git commit -m "feat: your improvement"
git push origin main

# 2. Update the version in pyproject.toml
#    e.g. version = "1.7.6" → version = "1.8.0"

# 3. Tag the release
git tag -a v1.8.0 -m "Release v1.8.0 — description of changes"
git push origin v1.8.0
```

```bash
# ── In the consumer repo ──

# Option A: Update the default in all workflows (recommended for permanent upgrades)
sed -i "s/vars.CLI_REPO_REF || 'v1.7.6'/vars.CLI_REPO_REF || 'v1.8.0'/g" \
  .github/workflows/*.yml
git add -A && git commit -m "chore: bump CLI to v1.8.0"
git push origin main

# Option B: Set a repo variable (no code change required)
#   Settings → Variables → CLI_REPO_REF = v1.8.0
```

### What Happens If You Forget

- **Nothing breaks** — workflows keep using the pinned tag (e.g. `v1.7.6`)
- You just won't get the latest CLI features or fixes until you update
- This is intentional: consumer repos are stable until you choose to upgrade

### Quick Checklist

| Step | Where | Command / Action |
|------|-------|------------------|
| 1. Code & push | CLI repo | `git commit` + `git push` |
| 2. Bump version | CLI repo | Edit `pyproject.toml` |
| 3. Tag release | CLI repo | `git tag -a vX.Y.Z` + `git push origin vX.Y.Z` |
| 4. Update consumer | Consumer repo | `sed` the default OR set `CLI_REPO_REF` variable |
| 5. Verify | Consumer repo | Run any workflow — check install step in logs |

---

## 12. Customising for Your Own Project

Once you've validated the lifecycle with the demo configs, customise for your real project:

### Change Workspace Names

Set the `PROJECT_PREFIX` repo variable (Settings → Variables):

```
PROJECT_PREFIX = sales-analytics
```

This automatically renames all workspaces, the pipeline, and feature workspaces.

### Add Resources

Edit `config/projects/demo/base_workspace.yaml`:

```yaml
lakehouses:
  - name: lh_bronze
    folder: Bronze
  - name: lh_silver
    folder: Silver
  - name: lh_gold
    folder: Gold

notebooks:
  - name: ingest_data
    folder: Bronze
  - name: transform_data
    folder: Silver
  - name: aggregate_reports
    folder: Gold

# Add generic Fabric resources (Eventstream, KQL Database, etc.)
resources:
  - type: Eventstream
    name: iot_ingestion
  - type: KQLDatabase
    name: realtime_analytics
```

### Multi-Project Setup

Create additional config directories:

```
config/projects/
├── demo/                          # Demo project (keep as reference)
│   ├── base_workspace.yaml
│   └── feature_workspace_demo.yaml
├── sales/                         # Sales analytics project
│   ├── base_workspace.yaml
│   └── feature_workspace.yaml
└── compliance/                    # Compliance reporting
    ├── base_workspace.yaml
    └── feature_workspace.yaml
```

Update `FEATURE_WORKSPACE_CONFIG` repo variable if you add multiple projects, or name your feature configs `feature_*.yaml` so the auto-discovery finds them.

### Point to a Different CLI Version

Set the `CLI_REPO_REF` repo variable to a specific tag or branch:

```
CLI_REPO_REF = v1.7.6
```

### Use Your Own CLI Fork

Set the `CLI_REPO_URL` variable:

```
CLI_REPO_URL = github.com/your-org/your-cli-fork
```

---

## 13. Architecture Reference

### Workflow Trigger Map

```
                    push feature/*        merge PR to main        manual
                         │                      │                   │
                         ▼                      ▼                   ▼
              ┌─────────────────┐    ┌─────────────────┐  ┌──────────────────┐
              │  Create Feature │    │  Cleanup Feature │  │  Promote Test →  │
              │    Workspace    │    │    Workspace     │  │    Production    │
              └─────────────────┘    └────────┬────────┘  └──────────────────┘
                                              │
                                    push to main triggers
                                              │
                                              ▼
                                   ┌─────────────────┐
                                   │ Promote Dev →    │
                                   │    Test          │
                                   └─────────────────┘
```

### Environment Variable Resolution

The YAML configs use `${VAR_NAME}` placeholders. These are resolved at runtime:

1. **In workflows**: GitHub Actions sets environment variables from secrets and variables
2. **In the CLI**: The deployer resolves `${VAR_NAME}` patterns against the shell environment
3. **In promote workflows**: A Python `re.sub` regex resolves `${VAR_NAME}` in the pipeline name read from YAML:

```python
# This is how promote workflows resolve config values
import os, re, yaml
config = yaml.safe_load(open('config/projects/demo/base_workspace.yaml'))
name = config['deployment_pipeline']['pipeline_name']
# Resolve ${VAR} patterns against environment variables
name = re.sub(r'\$\{(\w+)\}', lambda m: os.environ.get(m.group(1), m.group(0)), name)
```

### Files Reference

| File | Purpose |
|------|---------|
| `config/projects/demo/base_workspace.yaml` | Dev workspace + Deployment Pipeline definition |
| `config/projects/demo/feature_workspace_demo.yaml` | Feature workspace template |
| `.github/workflows/ci.yml` | CI validation (YAML lint, secret scan) |
| `.github/workflows/setup-base-workspaces.yml` | One-time Dev workspace setup |
| `.github/workflows/feature-workspace-create.yml` | Auto-provision on `feature/*` push |
| `.github/workflows/feature-workspace-cleanup.yml` | Auto-destroy on PR merge |
| `.github/workflows/promote-dev-to-test.yml` | Auto-promote Dev → Test on push to `main` |
| `.github/workflows/promote-test-to-prod.yml` | Manual promote Test → Prod |

### Secrets & Variables Quick Reference

**Secrets** (sensitive, encrypted):
```
AZURE_TENANT_ID          → Entra ID tenant
AZURE_CLIENT_ID          → SP application ID
AZURE_CLIENT_SECRET      → SP secret
FABRIC_GITHUB_TOKEN      → GitHub PAT
FABRIC_CAPACITY_ID       → Fabric capacity GUID
DEV_ADMIN_OBJECT_ID      → SP's Object ID (workspace admin)
```

**Variables** (non-sensitive, with defaults):
```
PROJECT_PREFIX           → Default: fabric-cicd-demo
CLI_REPO_URL             → Default: github.com/your-org/your-cli-repo
CLI_REPO_REF             → Default: v1.7.6  (pinned to a release tag)
FABRIC_CLI_VERSION       → Default: 1.3.1
FEATURE_WORKSPACE_CONFIG → Default: auto-discovered
```

---

## Appendix: Security Considerations

- **Never commit secrets** to the repo — always use GitHub Secrets
- **PAT rotation**: Set a short expiry on your GitHub PAT and rotate regularly
- **SP secret rotation**: Azure SP secrets expire (default: 2 years). Set a calendar reminder.
- **Least privilege**: The SP only needs Fabric API access and workspace admin — don't give it Azure subscription Owner
- **Audit trail**: The CLI writes structured audit logs (JSONL) for every operation. Review these for compliance.
