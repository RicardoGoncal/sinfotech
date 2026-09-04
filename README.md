# Sinfotech Cloud Platform

Plataforma de infraestrutura como código (IaC) e automação para provisionamento de um ecossistema completo focado em **criação de aplicativos, microsserviços e ferramentas de Inteligência Artificial (IA)**.

A stack utiliza **Oracle Cloud Infrastructure (OCI)** com **Terraform**, **Ansible**, **Coolify** (PaaS self-hosted) e **CLI Proxy API** (gestão de proxies e autenticação OAuth para ferramentas e modelos de IA).

---

## 🚀 Visão Geral e Arquitetura

O projeto permite subir e gerenciar de ponta a ponta um ambiente pronto para produção e desenvolvimento contínuo:

1. **Infraestrutura (OCI + Terraform):**
   - Criação de Bucket/Object Storage remoto para armazenamento seguro de estado (`tfstate`).
   - Provisionamento de Rede (VCN, Subnets públicas, Security Lists com regras de firewall necessárias).
   - Instância de Máquina Virtual (VM) dimensionada para suportar contêineres e aplicações.

2. **Configuração e Provisionamento (Ansible):**
   - Atualização de pacotes do sistema operacional.
   - Instalação das dependências básicas (`curl`, `wget`, `git`, `jq`).
   - Instalação e inicialização do **Coolify** (incluindo Docker e Docker Compose).

3. **Plataforma de Aplicações & Serviços (Coolify):**
   - Painel PaaS para deploy rápido de bancos de dados, APIs, microsserviços, bots e frontends.
   - Gerenciamento automático de certificados SSL/TLS via Traefik.

4. **Ferramentas de IA & Automação (CLI Proxy API):**
   - Proxy para provedores e modelos de IA.
   - Suporte a fluxos de autenticação OAuth de CLI (com suporte a túnel SSH para callbacks locais).

---

## 📁 Estrutura do Projeto

```text
├── terraform/
│   ├── global.tfvars               # Variáveis compartilhadas da OCI (compartment, tenancy, chaves)
│   ├── 00-backend-setup/           # Provisiona o Object Storage para o remote state do Terraform
│   │   ├── maint.tf
│   │   ├── variables.tf
│   │   └── output.tf
│   └── 01-vmcoolify/               # Provisiona a VM, VCN, Subnet e regras de firewall
│       ├── backend.tf              # Configuração do backend remoto OCI
│       ├── maint.tf                # Instância de computação
│       ├── network.tf              # Recursos de rede (VCN, Internet Gateway, Security List)
│       ├── provider.tf             # Provedor OCI
│       ├── variables.tf            # Variáveis específicas da VM
│       └── outputs.tf              # Saídas (IP público, OCID, etc.)
│
└── vm-configs/
    ├── ansible/
    │   ├── inventory.ini           # Inventário com IP da VM criada
    │   ├── setup-coolify.yaml      # Playbook de instalação do Coolify e dependências
    │   ├── coolify.sql             # Dump de banco para restauração/backup do Coolify
    │   └── coolify-backup.tar.gz   # Backup compactado dos dados do Coolify
    │
    ├── cliproxy/
    │   ├── docker-compose.yml      # Subida do CLI Proxy API integrado ao ambiente
    │   ├── config.yaml             # Configurações ativas do CLI Proxy
    │   └── config.example.yaml     # Exemplo de configuração
    │
    └── observabilidade/
         ├── docker-compose.yml      # Compose customizado de Prometheus + Grafana com limites de storage
         ├── prometheus.yml          # Configuração de targets/scrape do Prometheus
         └── observabilidade.md      # Guia e anotações sobre a stack de monitoramento
    ```

---

## 🛠️ Pré-requisitos

- [Terraform](https://developer.hashicorp.com/terraform/downloads) (>= 1.5.0)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
- Conta na **Oracle Cloud Infrastructure (OCI)** com permissões administrativas e chaves de API configuradas.
- Chave SSH (par de chaves pública e privada) para acesso à VM.

---

## 📋 Guia de Implantação

### 1. Configurar Variáveis da OCI

Copie ou edite o arquivo `terraform/global.tfvars` com suas credenciais OCI:

```hcl
tenancy_ocid     = "ocid1.tenancy.oc1..exemplo"
user_ocid        = "ocid1.user.oc1..exemplo"
fingerprint      = "xx:xx:xx:xx:xx:xx:xx:xx"
private_key_path = "~/.oci/oci_api_key.pem"
compartment_ocid = "ocid1.compartment.oc1..exemplo"
region           = "sa-saopaulo-1"
```

---

### 2. Subir o Backend Remoto (Terraform)

Cria o bucket para armazenar o estado das próximas etapas:

```bash
cd terraform/00-backend-setup
terraform init
terraform apply -var-file="../global.tfvars"
```

Guarde os outputs gerados (`bucket_name`, `namespace`, etc.).

---

### 3. Provisionar a VM e Rede (Terraform)

```bash
cd ../01-vmcoolify
terraform init
terraform apply -var-file="../global.tfvars"
```

Ao final, anote o **IP público** gerado no output.

---

### 4. Configurar Servidor e Instalar o Coolify (Ansible)

1. Atualize o arquivo `vm-configs/ansible/inventory.ini` inserindo o IP público da sua VM:

```ini
[coolify]
SEU_IP_PUBLICO ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
```

2. Execute o playbook de configuração:

```bash
cd ../../vm-configs/ansible
ansible-playbook -i inventory.ini setup-coolify.yaml
```

Após a execução, o **Coolify** estará ativo na porta `8000`:
```text
http://<IP_DA_VM>:8000
```

---

### 5. Configurar o CLI Proxy API

O CLI Proxy gerencia tokens e autenticações com múltiplos provedores/modelos de IA.

1. Conecte-se à VM ou configure o diretório `/data/coolify-apps/cliproxy/`:
   ```bash
   sudo mkdir -p /data/coolify-apps/cliproxy
   sudo cp vm-configs/cliproxy/config.yaml /data/coolify-apps/cliproxy/
   ```

2. Suba o serviço usando o Docker Compose ou via painel do Coolify:
   ```bash
   cd vm-configs/cliproxy
   docker compose up -d
   ```

#### Túnel SSH para Callbacks OAuth:
As portas de callback (`8085`, `1455`, `54545`, `51121`, `11451`) são mantidas fechadas no firewall da OCI por segurança. Para autenticações locais, utilize redirecionamento de portas via túnel SSH:

```bash
ssh -L 8085:localhost:8085 -L 1455:localhost:1455 -L 54545:localhost:54545 ubuntu@<IP_DA_VM>
```

---

## 🧩 Adicionando Novos Serviços e Ferramentas

Com a base instalada, novos recursos podem ser adicionados rapidamente:

- **Bancos de Dados & Caches:** Redis, PostgreSQL, MySQL ou MongoDB com deploy em 1 clique via Coolify.
- **Aplicações e APIs:** Node.js, Python/FastAPI, Go, Dockerfiles personalizados sincronizados via GitHub/GitLab.
- **Ecossistema de IA & Automação:**
  - Pipelines e automações com **N8N** / **Flowise**.
  - Modelos locais e inferência com **Ollama** / **vLLM**.
  - Interfaces como **Open WebUI**.
  - Agentes e proxies integrados com **CLI Proxy API**.

---

## 🔒 Segurança

- **Firewall e Security Lists:** Apenas as portas estritamente necessárias (`22`, `80`, `443`, `8000`, `8317`) devem ser expostas na OCI.
- **Backends e Segredos:** Nunca envie ao controle de versão arquivos com chaves privadas (`.pem`), credenciais `.env` ou estados locais do Terraform contendo segredos.
