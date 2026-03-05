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

## Secrets File (~/ee)

Add environment variables to `~/ee` (sourced by .zshrc):

```bash
nvim ~/ee
# export ANTHROPIC_API_KEY="..."
# export OPENAI_API_KEY="..."
# export GITHUB_TOKEN="..."
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
```
