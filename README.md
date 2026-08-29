# vault

Configuração do HashiCorp Vault como plataforma centralizada de secrets e
controle de acesso, gerenciada por Terraform de forma declarativa.

```
GitHub User ──PAT──▶ Vault GitHub Auth ──teams──▶ Vault Policies ──▶ Secret Engines (KV v2)
```

- **[`vault/`](vault/)** — configuração Terraform e documentação completa:
  arquitetura, policies, como fazer login, como expandir.
  👉 **Comece por [`vault/README.md`](vault/README.md).**

## Princípio

O Terraform administra **estrutura e autorização** — auth methods, secret
engines, policies e o mapeamento de GitHub Teams para policies.

O Terraform **não** administra valores de secrets: tudo que passa por ele é
gravado em texto claro no state.

## Uso rápido

```bash
cd vault
export VAULT_ADDR="https://vault.example.com"
export VAULT_TOKEN="$(vault print token)"

terraform init
terraform plan
terraform apply
```

Login humano:

```bash
export VAULT_ADDR="https://vault.example.com"
export VAULT_AUTH_GITHUB_TOKEN="github_pat_xxxxx"   # PAT com read:org
vault login -method=github
```

## Qualidade

`.github/workflows/terraform.yml` roda em cada PR: `terraform fmt -check`,
`terraform validate`, `tflint`, checagem de sintaxe das policies com
`vault policy fmt`, e secret scan com `gitleaks`.

Localmente:

```bash
cd vault && terraform fmt -recursive && terraform validate
tflint --config "$(git rev-parse --show-toplevel)/.tflint.hcl" --recursive
```
