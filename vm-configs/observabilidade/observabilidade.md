# Stack de Observabilidade (Prometheus + Grafana)

Esta pasta contém as configurações para implantar a stack de monitoramento de métricas no ecossistema da máquina virtual via Coolify (GitOps).

---

## 🎯 Objetivo

Fornecer métricas em tempo real e visualização de consumo de recursos (CPU, RAM, Disco, Rede e contêineres Docker) da VM sem risco de esgotamento de disco (*disk full*), com deploy e atualizações gerenciados diretamente por este repositório Git.

---

## 🛡️ Medidas de Blindagem de Storage

A principal causa de falha em stacks de monitoramento é o crescimento contínuo do banco de séries temporais (TSDB) do Prometheus. No `docker-compose.yml`, blindamos isso definindo travas no comando de inicialização:

- `--storage.tsdb.retention.time=15d`: Limite de retenção temporal de dados em 15 dias.
- `--storage.tsdb.retention.size=10GB`: Limite máximo de tamanho do banco TSDB em 10GB.
- `--web.enable-lifecycle`: Permite recarregar configurações via API sem reiniciar o container.

---

## 📁 Arquivos da Stack

- **`Dockerfile`**:
  - Baseado na imagem oficial `prom/prometheus:latest`, copia o arquivo `prometheus.yml` diretamente para `/etc/prometheus/prometheus.yml` durante o build no Coolify, eliminando problemas de bind mount no host.
- **`docker-compose.yml`**:
  - **Prometheus**: Constrói a imagem via `build: .` com os limites de retenção e volume persistente para dados (`prometheus-data`).
  - **Grafana**: Painel de dashboards e alertas, integrado na mesma rede Docker interna e preparado para receber domínio com SSL pelo Coolify.
- **`prometheus.yml`**:
  - Arquivo de alvos de coleta (*scrape*). Inicialmente monitora o próprio Prometheus na porta interna `9090`.

---

## 🚀 Como Provisionar via Coolify (GitOps)

1. No painel do **Coolify**, acesse o seu **Projeto / Environment**.
2. Clique em **+ New Resource** e selecione **Git Repository (Source)**.
3. Escolha este repositório (`sinfotech`) e a branch que contém as alterações (ex: `feat/observabilidade` ou `main`).
4. Em **Build Pack**, selecione **Docker Compose**.
5. Preencha os caminhos:
   - **Base Directory**: `/vm-configs/observabilidade`
   - **Docker Compose Location**: `docker-compose.yml` (ou `/vm-configs/observabilidade/docker-compose.yml`)
6. Salve a configuração. O Coolify detectará os dois serviços:
   - **Grafana**: Configure o campo **Domains** com seu subdomínio público (ex: `https://grafana.sinfotechs.cloud`) para o Traefik emitir o SSL.
   - **Prometheus**: Mantenha sem domínio público (acessível internamente pelo Grafana em `http://prometheus:9090`).
7. Clique em **Deploy**.

---

## ⚙️ Pós-Instalação

1. Acesse o Grafana na URL configurada (usuário inicial: `admin`, senha inicial: `admin`) e defina sua nova senha.
2. Em **Connections > Data Sources**, adicione uma fonte **Prometheus** com a URL: `http://prometheus:9090`.
3. Salve e teste a conexão (**Save & test**).
4. Para adicionar novos coletores (*Node Exporter*, métricas de containers, etc.), edite `prometheus.yml` nesta pasta e faça o push. O Coolify reconstruirá a imagem e aplicará as mudanças automaticamente.
