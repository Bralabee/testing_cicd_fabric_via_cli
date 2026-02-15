# E2E Validation Report — From-Scratch Lifecycle Test

> **Date**: 15 February 2026  
> **Tester**: Automated (GitHub Copilot agent)  
> **Environment**: Live Microsoft Fabric + GitHub Actions  
> **Repos Tested**:
> - **Product (CLI)**: `BralaBee-LEIT/usf_fabric_cli_cicd_codebase` (commit `78ec813`)
> - **Consumer (Demo)**: `BralaBee-LEIT/fabric_cicd_test_repo` (commit `e03c952`)

---

## Test Objective

Validate the **complete Fabric CI/CD lifecycle** end-to-end against a live Microsoft Fabric
platform, simulating a new user starting from scratch. This validates both the parameterized
workflows and the [REPLICATION_GUIDE.md](REPLICATION_GUIDE.md).

---

## Pre-conditions

| Item | Status | Details |
|------|--------|---------|
| GitHub Secrets configured | ✅ | 9 secrets: AZURE_TENANT_ID, AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, FABRIC_GITHUB_TOKEN, FABRIC_CAPACITY_ID, DEV_ADMIN_OBJECT_ID, ADDITIONAL_ADMIN_PRINCIPAL_ID, ADDITIONAL_CONTRIBUTOR_PRINCIPAL_ID, AZURE_SUBSCRIPTION_ID |
| GitHub Repo Variables | ✅ None set | Tests backward-compatible defaults (`PROJECT_PREFIX=fabric-cicd-demo`, `CLI_REPO_REF=main`, `FABRIC_CLI_VERSION=1.3.1`) |
| Stale branches cleaned | ✅ | `feature/validate-refactor` deleted before test |
| Starting branch | ✅ `main` | Clean working tree |

---

## Phase 2 — Feature Branch Lifecycle

### 2a. Create Feature Workspace

| Step | Result |
|------|--------|
| Branch created | `feature/e2e-scratch-test` from `main` |
| Push to origin | Triggered workflow `feature-workspace-create.yml` |
| **Workflow Run** | ID: `22036146438` |
| **Duration** | 2m 27s |
| **Status** | ✅ **SUCCESS** |

**Workflow Execution Details:**

1. **Config Discovery**: Auto-found `config/projects/demo/feature_workspace_demo.yaml`
   (via `find config/projects -name "feature_*.yaml" -type f | head -1`)
2. **CLI Install**: `ms-fabric-cli==1.3.1` (pinned), CLI from
   `github.com/BralaBee-LEIT/usf_fabric_cli_cicd_codebase.git@main` (default URL)
3. **Credential Verification**: ✅ All credentials verified
4. **Workspace Created**: `fabric-cicd-demo-feature-e2e-scratch-test`
   - Workspace ID: `e1718a1d-9a12-467c-b63f-a3c321f686df`
5. **Resources Provisioned**:
   - Folders: Bronze, Silver, Gold
   - Lakehouse: `lh_bronze`
   - Notebook: `demo_notebook`
   - Principals: 2 workspace admins assigned
6. **Git Connected**: Branch `feature/e2e-scratch-test` linked to workspace
7. **Total deployment time**: 116.14 seconds

### 2b. PR Created

| Step | Result |
|------|--------|
| PR # | `#8` |
| Title | "test: e2e scratch test — validate full lifecycle" |
| URL | `https://github.com/BralaBee-LEIT/fabric_cicd_test_repo/pull/8` |

### 2c. Cleanup on Merge

| Step | Result |
|------|--------|
| PR merged | Squash merge + branch delete |
| Trigger | `pull_request: [closed]` event on `branches: [main]` |
| **Workflow Run** | ID: `22036193043` |
| **Duration** | 35s |
| **Status** | ✅ **SUCCESS** |

**Cleanup Execution Details:**

1. **Config Discovery**: Same auto-find pattern
2. **Branch Detection**: `feature/e2e-scratch-test` extracted from PR context
3. **Workspace Name Derived**: `fabric-cicd-demo-feature-e2e-scratch-test`
   (via `tr '/' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]'`)
4. **Destroy Command**: `fab rm fabric-cicd-demo-feature-e2e-scratch-test.Workspace --force`
5. **Result**: ✅ Workspace destroyed, capacity freed

---

## Phase 3 — Promotion (Dev → Test)

### Auto-Promote on Main Push

The E2E scratch test merged only `E2E_SCRATCH_TEST.md`, which matched the
`paths-ignore: ['**.md']` filter — so the promote workflow was **correctly skipped**.

A second push with non-`.md` files (the parameterization commit `e03c952`) triggered
the promotion:

| Step | Result |
|------|--------|
| Push to main | Commit `e03c952` (14 files, non-docs) |
| **Workflow Run** | ID: `22036247587` |
| **Duration** | ~1m 50s |
| **Status** | ✅ **SUCCESS** |

**Promotion Execution Details:**

1. **`PROJECT_PREFIX`**: `fabric-cicd-demo` (default, no repo variable set)
2. **Pipeline Name**: `fabric-cicd-demo-pipeline` (read from `base_workspace.yaml`)
3. **Pipeline ID**: `6472fa05-82f2-48ac-ab04-67734bca4251` (3 stages found)
4. **Wait for Git Sync**: 60-second wait completed
5. **Promotion**: Development (`8c9855d7`) → Test (`da0865cf`)
6. **Operation ID**: `d2bd7463-1c36-42ce-ab1e-e76e1417ca24`
7. **Result**: ✅ `Promotion succeeded: Development → Test`

---

## Summary

| Phase | Workflow | Run ID | Duration | Result |
|-------|----------|--------|----------|--------|
| Feature Create | `feature-workspace-create.yml` | `22036146438` | 2m 27s | ✅ Pass |
| Feature Cleanup | `feature-workspace-cleanup.yml` | `22036193043` | 35s | ✅ Pass |
| CI Validation | `ci.yml` | `22036191210` | 9s | ✅ Pass |
| Promote Dev→Test | `promote-dev-to-test.yml` | `22036247587` | ~1m 50s | ✅ Pass |

### Key Observations

1. **Backward Compatibility**: With zero repo variables set, all workflows use default
   fallbacks correctly. The `${{ vars.XXX || 'default' }}` pattern works as intended.

2. **Config Auto-Discovery**: The `find config/projects -name "feature_*.yaml"` pattern
   eliminates the need for users to manually specify config paths.

3. **Idempotent Cleanup**: The `--force` flag on destroy ensures clean teardown even if
   workspace state is partially provisioned.

4. **paths-ignore Correctness**: The promote workflow correctly skips `.md`-only commits,
   preventing unnecessary Fabric API calls.

5. **End-to-End Time**: Full feature branch lifecycle (create → merge → cleanup) completed
   in under 5 minutes total wall-clock time.

6. **Cleanup Trigger Design**: Cleanup fires on `pull_request: [closed]`, not on branch
   `delete`. This means cleanup only runs when PRs are merged/closed — directly deleting
   a remote branch will NOT trigger cleanup. This is documented in the REPLICATION_GUIDE.

---

## Artifacts

- [REPLICATION_GUIDE.md](REPLICATION_GUIDE.md) — Step-by-step setup guide for new users
- [Feature Branch Guide](../../usf_fabric_cli_cicd/docs/01_User_Guides/10_Feature_Branch_Workspace_Guide.md) — Detailed workflow reference in CLI repo
