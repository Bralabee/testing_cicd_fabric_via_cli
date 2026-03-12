# Changelog

## [2026-03-09] — Parity Update

### Added
- `deploy-dev.yml` workflow — auto-organizes folders in Dev workspaces after Git Sync
- `discover-folders` CI job — auto-discovers new folders from feature workspaces on PRs
- `organize-folders` post-promotion steps in promote-dev-to-test and promote-test-to-prod
- Makefile with 20 automation targets (new-repo, new-project, scaffold, validate, etc.)
- `config/projects/_templates/standard_data_product/` — reusable 8-folder template
- Governance principals (ADDITIONAL_ADMIN_PRINCIPAL_ID, ADDITIONAL_CONTRIBUTOR_PRINCIPAL_ID) in all workflows
- Project-specific principals (DEMO_ADMIN_ID/MEMBERS_ID, SALES_ANALYTICS_ADMIN_ID/MEMBERS_ID) in all workflows
- Documentation: 00_START_HERE, 04_QUICK_REFERENCE, 07_CONSUMER_REPO_SETUP_GUIDE, ONBOARDING_EXISTING_WORKSPACES, WORKFLOW_REFERENCE

### Changed
- Promotion workflows now use manual dispatch with project selector (previously auto on push to main)
- Feature workspace workflows now support multi-project branch naming (feature/<project>/<name>)
- All workflows use pinned action SHAs and GIT_AUTH_TOKEN pattern for secure CLI install
- Project configs updated to 8-folder convention with folder_rules (was Bronze/Silver/Gold)
- All project configs use project-specific git_directory (was /)
- CI workflow now validates git_directory per project

### Fixed
- Orphaned `type: Group` lines in project config YAML files
- Multi-project workflow CLI version bumped from v1.7.16 to v1.8.3

## [2026-03-09] — v1.8.3 CLI Update

### Changed
- Updated CLI version references to v1.8.3 in active workflows

## [Previous] — See git log for earlier changes
