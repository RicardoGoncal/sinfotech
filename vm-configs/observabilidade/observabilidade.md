# Stack de Observabilidade (Prometheus + Grafana)

Esta pasta contem os arquivos de configuracao para implantar a stack de monitoramento de metricas no ecossistema da VM via Coolify (GitOps).

---

## Objetivo

Fornecer metricas em tempo real e visualizacao de consumo de recursos (CPU, RAM, Disco, Rede e conteineres Docker) da VM sem risco de esgotamento de disco (*disk full*), com deploy e atualizacoes gerenciados diretamente por este repositorio Git.

---

## Blindagem contra Vazamento de Storage

A principal causa de falha em stacks de monitoramento e o crescimento descontrolado do banco de series temporais (TSDB) do Prometheus. No nosso docker-compose.yml, blindamos isso definindo travas rigidas nos parametros de inicializacao:

- --storage.tsdb.retention.time=15d: Limite maximo de retencao temporal de dados em 15 dias.
- --storage.tsdb.retention.size=10GB: Limite maximo de tamanho do banco TSDB em 10GB.
- --web.enable-lifecycle: Permite recarregar alteracoes de configuracao via API sem reiniciar o container.

---

## Arquivos da Stack

- **docker-compose.yml**:
  - **Prometheus**: Banco de metricas configurado com retencao restrita e bind mount do ./prometheus.yml.
  - **Grafana**: Painel de dashboards e alertas, integrado na mesma rede Docker interna e preparado para receber dominio com SSL via Traefik no Coolify.
- **prometheus.yml**:
  - Arquivo de configuracao dos alvos de coleta (*scrape*). Inicialmente configurado para monitorar a si mesmo na porta 9090.

---

## Como Provisionar via Coolify (GitOps)

Em vez de colar texto avulso no painel ou subir containers manuais, a stack fica sincronizada com este repositorio:

1. No painel do **Coolify**, acesse o seu **Projeto / Environment**.
2. Clique em **+ New Resource** e selecione **Git Repository (Source)**.
3. Escolha este repositorio (sinfotech) e a branch principal (main).
4. Em **Build Pack**, selecione **Docker Compose**.
5. Preencha os caminhos:
   - **Base Directory**: /vm-configs/observabilidade
   - **Docker Compose Location**: docker-compose.yml (ou /vm-configs/observabilidade/docker-compose.yml)
6. Salve a configuracao. O Coolify identificara os servicos:
   - **Grafana**: Configure o campo **Domains** com o seu subdominio publico (ex: https://grafana.sinfotechs.cloud) para geracao automatica de SSL.
   - **Prometheus**: Mantenha sem dominio publico (ele opera internamente na rede Docker comunicando com o Grafana em http://prometheus:9090).
7. Clique em **Deploy**.

---

## Configuracao Pos-Deploy

1. Acesse a URL do Grafana (credenciais iniciais: dmin / dmin). O painel solicitara a troca imediata de senha no primeiro login.
2. Va em **Connections > Data Sources** e adicione **Prometheus**:
   - **Prometheus server URL**: http://prometheus:9090
3. Salve e teste a conexao (**Save & test**).
4. Para adicionar novos coletores (como *Node Exporter* para CPU/RAM da maquina ou metricas de microsservicos), basta editar o arquivo prometheus.yml nesta pasta e commitar. O Coolify sincronizara as alteracoes automaticamente.
