# Refactor Validation Test

Validates that the `usf_fabric_cli_cicd` consolidation refactor (scripts/ and templates/
moved into `src/usf_fabric_cli/` package) works correctly end-to-end.

## What Changed (Product Repo)
- Top-level `scripts/` → `src/usf_fabric_cli/scripts/`
- Top-level `templates/` → `src/usf_fabric_cli/templates/`
- Makefile, Dockerfile, CI workflow, and ~252 references updated
- 369 unit tests pass

## E2E Validation Steps
1. ✅ Setup Base Workspaces — Dev/Test/Prod created
2. 🔄 Feature Workspace — This branch triggers creation
3. ⬜ PR Merge — Triggers cleanup + Dev→Test promotion
4. ⬜ Manual Promote — Test→Prod

**Date**: $(date +%Y-%m-%d)
**Commit**: ab8eadf (product repo)
