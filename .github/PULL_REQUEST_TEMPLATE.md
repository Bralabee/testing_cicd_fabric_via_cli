## Description

<!-- Summary of changes to workspace configuration or workflows. -->

## Type of Change

- [ ] Configuration change (YAML workspace config)
- [ ] Workflow update (GitHub Actions)
- [ ] Documentation update

## Testing

- [ ] YAML config is valid (`python3 -c "import yaml; yaml.safe_load(open('config/...'))"`)
- [ ] No hardcoded secrets or credentials
- [ ] Environment variable placeholders (`${VAR_NAME}`) used correctly
- [ ] Tested with real feature branch (if workflow change)

## Security Checklist

- [ ] No secrets, tokens, or credentials committed
- [ ] All sensitive values use `${VAR_NAME}` substitution
- [ ] GitHub Actions secrets are properly referenced

## Reviewer Notes

<!-- Any specific areas you'd like reviewers to focus on -->
