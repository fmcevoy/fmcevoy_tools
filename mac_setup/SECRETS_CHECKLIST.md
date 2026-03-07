# Secrets & Post-Setup Checklist

After running `setup.sh`, configure these credentials manually.
These should NEVER be committed to version control.

## Git Identity

```bash
# Edit with your real name and email
nvim ~/.gitconfig.local
```

## GitHub / GitLab CLI

```bash
gh auth login
glab auth login
```

## AWS

```bash
# Configure AWS CLI
aws configure
# Or set up SSO profiles in ~/.aws/config
# Test with: aws sts get-caller-identity
# For role assumption: assume <profile-name>
```

## SSH Keys

```bash
# Generate new key if needed
ssh-keygen -t ed25519 -C "your@email.com"
# Add to agent
ssh-add ~/.ssh/id_ed25519
# Add public key to GitHub
gh ssh-key add ~/.ssh/id_ed25519.pub
```

## 1Password CLI

```bash
op signin
op vault list
```

## Kubernetes

```bash
# Configure kubeconfig
# Verify: kubectl cluster-info
# Tools: k9s, kns, kdash
```

## HashiCorp Vault

```bash
export VAULT_ADDR="https://vault.example.com"
vault login
```

## Teleport

```bash
tsh login --proxy=teleport.example.com
tsh status
```

## Claude Code MCP Servers

MCP servers are configured automatically by `setup.sh`. The GitHub token
is injected from `gh auth` at setup time. Some servers need extra config:

```bash
# Supabase — get token from supabase.com/dashboard/account/tokens
# Add to ~/ee:
# export SUPABASE_ACCESS_TOKEN="sbp_..."

# Docker — requires OrbStack or Docker Desktop running
# AWS CDK — uses AWS_PROFILE=default, configure with: aws configure
# Fly.io — authenticate with: fly auth login
# gcloud — authenticate with: gcloud auth login
```

MCP config lives in `~/.claude/.mcp.json` (not `settings.json`).
To verify MCP servers are loaded, restart Claude Code and run `/mcp`.

## Secrets File (~/ee)

Add environment variables to `~/ee` (sourced by .zshrc):

```bash
nvim ~/ee
# export ANTHROPIC_API_KEY="..."
# export OPENAI_API_KEY="..."
# export GITHUB_TOKEN="..."
# export SUPABASE_ACCESS_TOKEN="..."
```

## Verification

```bash
gh auth status
glab auth status
aws sts get-caller-identity
kubectl cluster-info
vault status
op vault list
tsh status
fly auth whoami
# Claude Code: run /mcp inside a session to verify MCP servers
```
