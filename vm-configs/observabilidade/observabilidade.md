# Stack de Observabilidade (Prometheus + Grafana)

Esta pasta contem as configuracoes para implantar a stack de monitoramento de metricas no ecossistema da maquina virtual via Coolify (GitOps).

---

## Objetivo

Fornecer metricas em tempo real e visualizacao de consumo de recursos (CPU, RAM, Disco, Rede e conteineres Docker) da VM sem risco de esgotamento de disco (*disk full*), com deploy e atualizacoes gerenciados diretamente por este repositorio Git.

---

## Medidas de Blindagem de Storage

A principal causa de falha em stacks de monitoramento e o crescimento continuo do banco de series temporais (TSDB) do Prometheus. No `docker-compose.yml`, blindamos isso definindo travas no comando de inicializacao:

- `--storage.tsdb.retention.time=15d`: Limite de retencao temporal de dados em 15 dias.
- `--storage.tsdb.retention.size=10GB`: Limite maximo de tamanho do banco TSDB em 10GB.
- `--web.enable-lifecycle`: Permite recarregar configuracoes via API sem reiniciar o container.

---

## Arquivos da Stack

- **`docker-compose.yml`**:
  - **Prometheus**: usa a imagem oficial `prom/prometheus:latest` (sem build, sem Dockerfile), com os limites de retencao acima e volume nomeado persistente para dados (`prometheus-data`). O arquivo de config e montado via **bind mount de caminho absoluto no host** (ver secao seguinte) — NAO via volume nomeado nem via caminho relativo do repositorio.
  - **Grafana**: painel de dashboards e alertas, integrado na mesma rede Docker interna e preparado para receber dominio com SSL pelo Coolify.
  - **Node Exporter**: coleta metricas do host/servidor OCI (CPU geral, RAM, Disco, IOPS, Carga, Rede da VM).
  - **cAdvisor**: coleta metricas de conteineres Docker do Coolify (CPU, RAM, Disco e Rede por container/projeto).
- **`prometheus.yml`** (nesta pasta, no git): copia de referencia dos alvos de coleta (*scrape*). Serve como fonte da verdade para copiar manualmente para o servidor (ver abaixo) — **o container NAO le este arquivo diretamente do checkout do git**.

---

## ⚠️ Por que o config NAO pode vir do repositorio (bind mount relativo quebra)

O Coolify roda o `docker compose` dentro de um diretorio de build **temporario e efemero** (`/artifacts/<hash>/...`), recriado a cada deploy. Um bind mount relativo como `./prometheus.yml:/etc/prometheus/prometheus.yml` falha de forma intermitente: o Docker as vezes cria um **diretorio vazio** chamado `prometheus.yml` no host antes de montar, e o container quebra tentando ler um diretorio onde esperava um arquivo.

A solucao (mesmo padrao usado no `vm-configs/cliproxy`): o arquivo real fica num **caminho fixo no host**, fora do checkout do git, e o `docker-compose.yml` aponta pra ele via **caminho absoluto**. Esse caminho sobrevive a qualquer redeploy.

### Passo a passo — criar/atualizar o prometheus.yml no servidor via SSH

```bash
ssh ubuntu@193.122.218.251

sudo mkdir -p /data/coolify-apps/observabilidade
sudo nano /data/coolify-apps/observabilidade/prometheus.yml
```

Cole o conteudo (mantenha sincronizado com o `prometheus.yml` desta pasta no git, que serve de referencia):

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
```

Salve (`Ctrl+O`, `Enter`, `Ctrl+X`) e proteja o arquivo:

```bash
sudo chmod 644 /data/coolify-apps/observabilidade/prometheus.yml
```

O `docker-compose.yml` referencia esse caminho assim:

```yaml
volumes:
  - /data/coolify-apps/observabilidade/prometheus.yml:/etc/prometheus/prometheus.yml
```

---

## Como Provisionar via Coolify (GitOps)

1. No painel do **Coolify**, acesse o seu **Projeto / Environment**.
2. Clique em **+ New Resource** e selecione **Git Repository (Source)**.
3. Escolha este repositorio (`sinfotech`) e a branch que contem as alteracoes (ex: `feat/observabilidade` ou `main`).
4. Em **Build Pack**, selecione **Docker Compose**.
5. Preencha os caminhos:
   - **Base Directory**: `/vm-configs/observabilidade`
   - **Docker Compose Location**: `docker-compose.yml`
6. Salve a configuracao.
7. **Antes do primeiro deploy**, garanta que `/data/coolify-apps/observabilidade/prometheus.yml` ja existe no servidor (secao acima) — senao o container do Prometheus vai subir sem config valida.
8. Configure o dominio do Grafana em **Domains** (ex: `https://grafana.sinfotechs.cloud`) para o Traefik emitir o SSL. O Prometheus fica sem dominio publico (acessivel internamente pelo Grafana em `http://prometheus:9090`).
9. Clique em **Deploy**.

### ⚠️ Erro comum: "no service selected"

Esse erro acontece quando o Coolify perde a referencia de quais servicos do compose estao habilitados pra deploy (costuma ocorrer depois de editar o `docker-compose.yml` e salvar de novo). A correcao fica **fora** da tela de um servico individual:

1. Na tela de um dos servicos (ex: Prometheus), clique em **"← Back to service"** no menu lateral — isso volta pra pagina que lista os DOIS servicos (`prometheus` e `grafana`) juntos.
2. Confirme que ambos aparecem marcados/habilitados para deploy. Se algum estiver desmarcado, marque.
3. Salve e so entao clique em **Deploy** novamente.

---

## Pos-Instalacao

1. Acesse o Grafana na URL configurada (usuario inicial: `admin`, senha inicial: `admin`) e defina sua nova senha. **Troque a senha padrao do `GF_SECURITY_ADMIN_PASSWORD` no `docker-compose.yml` tambem**, ela nao deve ficar como `admin` em producao.
2. Em **Connections > Data Sources**, adicione uma fonte **Prometheus** com a URL: `http://prometheus:9090`.
3. Salve e teste a conexao (**Save & test**).

## Atualizando os alvos de coleta (scrape_configs)

Como o config NAO vem mais do build/git, editar so o `prometheus.yml` desta pasta e dar push **nao e suficiente** — o passo manual no servidor e obrigatorio:

1. Edite `prometheus.yml` nesta pasta (git) e faca commit/push — mantem o repositorio como fonte de verdade documentada.
2. Edite tambem o arquivo real no servidor via SSH:
   ```bash
   ssh ubuntu@193.122.218.251
   sudo nano /data/coolify-apps/observabilidade/prometheus.yml
   ```
3. Recarregue o Prometheus sem reiniciar o container (usa o `--web.enable-lifecycle` ja habilitado):
   ```bash
   docker exec prometheus wget -qO- --post-data='' http://localhost:9090/-/reload
   ```
   Ou, se preferir garantir 100%, reinicie o container pelo Coolify (botao **Restart** no recurso do Prometheus).

---

## Dashboards Prontos no Grafana

Para importar no Grafana: va em **Dashboards** > **New** > **Import**, informe o ID e clique em **Load**.

### 1. Dashboard da VM Oracle Cloud (Host)
- **ID sugerido**: `1860` (Node Exporter Full)
- **O que monitora**:
  - Consumo geral de CPU (% e por core da VM ARM/Ampere)
  - Memoria RAM total, em uso, livre, cache e swap
  - Espaco livre e uso de disco (particoes / e block storage)
  - IOPS de disco e tráfego de rede da VM

### 2. Dashboard de Containers e Projetos do Coolify
- **ID sugerido**: `14282` ou `893` (Docker cAdvisor)
- **Golden Metrics por container**:
  - **Status Up/Down**: `time() - container_last_seen{name=~".+"} < 30`
  - **CPU %**: `sum(rate(container_cpu_usage_seconds_total{name=~"$container"}[1m])) by (name) * 100`
  - **Memoria RAM**: `container_memory_working_set_bytes{name=~"$container"}`
  - **I/O Disco (Bytes lidos/escritos)**: `sum(rate(container_fs_reads_bytes_total{name=~"$container"}[1m]) + rate(container_fs_writes_bytes_total{name=~"$container"}[1m])) by (name)`
  - **Trafego de Rede**: `sum(rate(container_network_receive_bytes_total{name=~"$container"}[1m])) by (name)`
