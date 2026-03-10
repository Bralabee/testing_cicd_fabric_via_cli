# Workflow Options: Single-Project vs Multi-Project

Choose your consumer repo strategy at project initiation time. Both are fully
implemented and ready to use — pick the one that fits your team's needs.

---

## Option A: Single-Project per Repo (current default)

**One consumer repo = one Fabric project.** This is how the repo ships.

The template includes **7 GitHub Actions workflows**: CI, setup, feature create,
feature cleanup, deploy-dev (auto-organize folders), promote Dev-to-Test, and
promote Test-to-Prod.

```
fabric_cicd_consumer_repo/          <- One repo per Fabric project
+-- .github/workflows/              <- 7 active workflows (single-project)
+-- config/projects/demo/
|   +-- base_workspace.yaml
|   +-- feature_workspace_demo.yaml
```

### When to use
- Different teams own different Fabric projects
- Different Service Principals needed per project (security isolation)
- Different promotion cadences (Project A auto-promotes, Project B is manual)
- You want the simplest possible workflow logic
- Enterprise/regulated environments where blast radius must be minimized

### How it works
| What | How |
|:---|:---|
| Setup workspace | Actions -> "Setup Base Workspaces" -> Run |
| Feature branch | `git checkout -b feature/my-feature` |
| Feature cleanup | Automatic on PR merge |
| Dev folders organized | Automatic on push to main (via `deploy-dev.yml` running `organize-folders`) |
| Dev -> Test | Automatic on push to main (or manual dispatch) |
| Test -> Prod | Manual dispatch, type "PROMOTE" |

> **deploy-dev.yml** is a shared workflow that auto-runs after every push to `main`.
> It calls `fabric-cicd organize-folders` to move items back into their correct
> folders after Fabric Git Sync (which always drops items at the workspace root).

### Branch convention
```
feature/<feature-name>
```
Examples: `feature/add-gold-table`, `feature/fix-pipeline`

---

## Option B: Multi-Project in One Repo

**One consumer repo = multiple Fabric projects.** Workflows in
`.github/multi-project-workflows/` handle project selection automatically.

The multi-project option also uses **7 workflows** but with project selection
dropdowns and matrix strategies for parallel operations. The `deploy-dev.yml`
workflow auto-detects which projects were changed in a push to `main` and runs
`organize-folders` only on affected workspaces. The `discover-folders` feature
(available in CI) auto-discovers new folders from feature workspaces.

```
fabric_cicd_consumer_repo/
+-- .github/
|   +-- workflows/                    <- Replace with multi-project versions
|   +-- multi-project-workflows/      <- Source of truth for Option B
+-- config/projects/
|   +-- demo/                         <- Project 1
|   |   +-- base_workspace.yaml
|   |   +-- feature_workspace_demo.yaml
|   +-- sales_analytics/             <- Project 2
|       +-- base_workspace.yaml
|       +-- feature_workspace.yaml
```

### When to use
- Small team managing multiple related Fabric projects
- Same Service Principal handles all projects
- Same promotion rules apply to all projects
- You want fewer repos to manage
- Projects share the same capacity and admin group

### How it works
| What | How |
|:---|:---|
| Setup workspace | Actions -> "Setup Base Workspaces" -> **select project** -> Run |
| Feature branch | `git checkout -b feature/<project>/<feature-name>` |
| Feature cleanup | Automatic on PR merge (project extracted from branch name) |
| Dev folders organized | Automatic on push to main (only changed projects, via `deploy-dev.yml`) |
| Dev -> Test | Manual dispatch -> **select project** -> Run |
| Test -> Prod | Manual dispatch -> **select project** -> type "PROMOTE" |

### Branch convention
```
feature/<project>/<feature-name>
```
Examples: `feature/demo/add-gold-table`, `feature/sales_analytics/fix-pipeline`

> **Fallback**: If you push `feature/something` (no project segment), it defaults
> to the `DEFAULT_PROJECT` repo variable (or `demo` if not set).

---

## Switching from Option A to Option B

```bash
# 1. Back up current workflows (optional)
mkdir -p .github/single-project-workflows
cp .github/workflows/*.yml .github/single-project-workflows/

# 2. Replace active workflows with multi-project versions
cp .github/multi-project-workflows/*.yml .github/workflows/

# 3. Add new project configs (copy + customize)
cp -r config/projects/demo config/projects/my_new_project
# Edit config/projects/my_new_project/base_workspace.yaml

# 4. Update the project choice lists in workflows that use `type: choice`
#    Search for "# ➕ Add new projects here" in the workflow files:
#    - setup-base-workspaces.yml  (inputs.project.options)
#    - promote-test-to-prod.yml   (inputs.project.options)

# 5. Commit and push
git add -A && git commit -m "feat: switch to multi-project workflows"
git push
```

## Switching from Option B back to Option A

```bash
# Restore single-project workflows
cp .github/single-project-workflows/*.yml .github/workflows/
git add -A && git commit -m "revert: switch back to single-project workflows"
```

---

## Side-by-Side Comparison

| Aspect | Option A (Single) | Option B (Multi) |
|:---|:---|:---|
| **Repos to manage** | One per project | One for all |
| **Secrets isolation** | Full (per-repo secrets) | Shared (all projects use same SP) |
| **Branch naming** | `feature/<name>` | `feature/<project>/<name>` |
| **Setup workflow** | Deploys the one project | Select project from dropdown |
| **Folder organization** | Auto on push to main | Auto on push to main (only changed projects) |
| **Promotion** | One project promoted | Select project from dropdown |
| **Adding a project** | Fork/copy the repo | Add config folder + update choice lists |
| **CODEOWNERS** | Per-repo | Shared (can use path-based rules) |
| **Complexity** | Simple | Moderate |
| **Blast radius** | One project | All projects in the repo |

---

## Adding a New Project (Option B)

1. **Create config folder:**
   ```bash
   mkdir -p config/projects/my_project
   ```

2. **Copy and customize YAML configs:**
   ```bash
   cp config/projects/demo/base_workspace.yaml config/projects/my_project/
   cp config/projects/demo/feature_workspace_demo.yaml config/projects/my_project/feature_workspace.yaml
   # Edit both files: change workspace names, resources, etc.
   ```

3. **Update workflow choice lists** (only needed for manual-dispatch workflows):
   - `.github/workflows/setup-base-workspaces.yml` → `inputs.project.options`
   - `.github/workflows/promote-test-to-prod.yml` → `inputs.project.options`

   The `deploy-dev.yml` and `promote-dev-to-test.yml` auto-discover projects -- no change needed.

4. **Run initial setup:**
   ```
   Actions → "Setup Base Workspaces" → project: my_project → Run
   ```

5. **Start developing:**
   ```bash
   git checkout -b feature/my_project/first-feature
   ```

---

## Repo Variables (Multi-Project)

In addition to the standard repo variables, Option B supports:

| Variable | Default | Purpose |
|:---|:---|:---|
| `DEFAULT_PROJECT` | `demo` | Fallback project when branch name doesn't include a project segment |
| `FEATURE_WORKSPACE_CONFIG` | *(auto-discovered)* | Override: force all feature workspaces to use a specific config |

---

## Key Features (Both Options)

### deploy-dev.yml -- Auto-Organize Folders

The `deploy-dev.yml` workflow runs automatically on every push to `main`. It calls
`fabric-cicd organize-folders` to move Fabric items back into their correct folders
after Git Sync.

**Why this is needed**: Fabric Git Sync does not preserve folder assignments. When
content syncs into a workspace, all items land at the workspace root. The
`organize-folders` command reads `folder_rules` from `base_workspace.yaml` and moves
items into the designated folders.

In Option B (multi-project), the workflow uses `git diff` to detect which projects
were changed in the push and only organizes affected workspaces.

### discover-folders -- Auto-Detect New Folders

The `discover-folders` CLI command (and optional CI job) scans feature workspaces for
new folders and item-to-folder mappings not yet in the YAML config. When run in CI on
PRs from `feature/*` branches, it auto-commits updates to the PR branch -- ensuring
`folder_rules` are current before merge.

```bash
# Manual discovery
fabric-cicd discover-folders config/projects/<project>/base_workspace.yaml \
    --branch feature/<project>/<description>

# Dry run
fabric-cicd discover-folders config/projects/<project>/base_workspace.yaml \
    --workspace "My Feature Workspace" --dry-run
```

### scaffold -- Import Existing Workspaces

The `fabric-cicd scaffold` command (and `make scaffold` target) reads a live Fabric
workspace and generates YAML config templates. This is the fastest way to bring
existing workspaces under CI/CD management. See
[Onboarding Existing Workspaces](ONBOARDING_EXISTING_WORKSPACES.md) for the full guide.
