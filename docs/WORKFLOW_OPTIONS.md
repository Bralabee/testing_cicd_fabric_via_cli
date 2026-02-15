# Workflow Options: Single-Project vs Multi-Project

Choose your consumer repo strategy at project initiation time. Both are fully
implemented and ready to use — pick the one that fits your team's needs.

---

## Option A: Single-Project per Repo (current default)

**One consumer repo = one Fabric project.** This is how the repo ships.

```
fabric_cicd_consumer_repo/          ← One repo per Fabric project
├── .github/workflows/              ← Active workflows (single-project)
├── config/projects/demo/
│   ├── base_workspace.yaml
│   └── feature_workspace_demo.yaml
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
| Setup workspace | Actions → "Setup Base Workspaces" → Run |
| Feature branch | `git checkout -b feature/my-feature` |
| Feature cleanup | Automatic on PR merge |
| Dev → Test | Automatic on push to main (or manual if you change the trigger) |
| Test → Prod | Manual dispatch, type "PROMOTE" |

### Branch convention
```
feature/<feature-name>
```
Examples: `feature/add-gold-table`, `feature/fix-pipeline`

---

## Option B: Multi-Project in One Repo

**One consumer repo = multiple Fabric projects.** Workflows in
`.github/multi-project-workflows/` handle project selection automatically.

```
fabric_cicd_consumer_repo/
├── .github/
│   ├── workflows/                    ← Replace with multi-project versions
│   └── multi-project-workflows/      ← Source of truth for Option B
├── config/projects/
│   ├── demo/                         ← Project 1
│   │   ├── base_workspace.yaml
│   │   └── feature_workspace_demo.yaml
│   └── sales_analytics/             ← Project 2
│       ├── base_workspace.yaml
│       └── feature_workspace.yaml
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
| Setup workspace | Actions → "Setup Base Workspaces" → **select project** → Run |
| Feature branch | `git checkout -b feature/<project>/<feature-name>` |
| Feature cleanup | Automatic on PR merge (project extracted from branch name) |
| Dev → Test | All projects promoted in parallel on push to main |
| Test → Prod | Manual dispatch → **select project** → type "PROMOTE" |

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
| **Promotion** | One project promoted | All projects promoted in parallel (matrix) |
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

   The `promote-dev-to-test.yml` auto-discovers projects — no change needed.

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
