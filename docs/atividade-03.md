# Atividade 3 — Automatizar de verdade

## 1. Objetivo

Nesta atividade o ufla-devops-shop foi colocado no ar como um serviço Linux gerenciado
pelo systemd: instalação idempotente via `deploy.sh`, backup diário automatizado via
systemd timer, e Nginx como proxy reverso com TLS na frente da aplicação.

## 2. Estrutura entregue

```text
scripts/
├── deploy.sh
└── backup.sh

systemd/
├── ufla-shop.service
├── ufla-shop-backup.service
└── ufla-shop-backup.timer

nginx/
└── loja.conf

docs/
└── atividade-03.md
```

## 3. Como rodar numa máquina limpa

```bash
git clone https://github.com/Thiagoferreira13/ufla-devops-shop.git
cd ufla-devops-shop
git switch atividade-03
sudo ./scripts/deploy.sh
```

O script:
1. instala as dependências de sistema (Python, PostgreSQL, Redis, Nginx, OpenSSL);
2. cria o usuário de sistema `ufla-shop` (se não existir);
3. sincroniza o código para `/opt/ufla-shop`, cria o venv e instala `requirements.txt`;
4. cria `/etc/ufla-shop.env` a partir de `/etc/ufla-shop.env.example` (editar com a senha real);
5. gera o certificado TLS autoassinado (`loja.pem` / `loja.key`) em `/etc/nginx/ssl`;
6. instala as units do systemd, roda `daemon-reload`, habilita e reinicia o serviço;
7. instala e ativa `nginx/loja.conf`;
8. valida a aplicação com healthcheck em `http://127.0.0.1:8000/ready` (até 10 tentativas, 1s de intervalo).

## 4. Evidências

### a) `systemctl status ufla-shop` após `kill -9`

Comando:
```bash
sudo systemctl kill -s SIGKILL ufla-shop
sleep 5
sudo systemctl status ufla-shop --no-pager
```

Saída:
```
● ufla-shop.service - API do ufla-devops-shop
     Loaded: loaded (/etc/systemd/system/ufla-shop.service; enabled; preset: enabled)
     Active: active (running) since Fri 2026-09-25 09:36:39 -03; 25s ago
   Main PID: 117914 (uvicorn)
      Tasks: 1 (limit: 16895)
     Memory: 42.0M (peak: 42.6M)
        CPU: 594ms
     CGroup: /system.slice/ufla-shop.service
             └─117914 /opt/ufla-shop/.venv/bin/python3 /opt/ufla-shop/.venv/bin/uvicorn app:api --host 127.0.0.1 --port 8000

set 25 09:36:39 thiagopc systemd[1]: ufla-shop.service: Scheduled restart job, restart counter is at 3.
set 25 09:36:39 thiagopc systemd[1]: Started ufla-shop.service - API do ufla-devops-shop.
set 25 09:36:39 thiagopc uvicorn[117914]: INFO:     Started server process [117914]
set 25 09:36:39 thiagopc uvicorn[117914]: INFO:     Waiting for application startup.
set 25 09:36:39 thiagopc uvicorn[117914]: 2026-09-25 09:36:39,813 INFO loja: ufla-devops-shop 1.0.0 subindo (banco=postgresql, cache=redis, instancia=thiagopc)
set 25 09:36:39 thiagopc uvicorn[117914]: 2026-09-25 09:36:39,898 INFO loja.banco: banco pronto (modo postgresql)
set 25 09:36:39 thiagopc uvicorn[117914]: INFO:     Application startup complete.
set 25 09:36:39 thiagopc uvicorn[117914]: INFO:     Uvicorn running on http://127.0.0.1:8000 (Press CTRL+C to quit)
```

O serviço foi morto com `SIGKILL` e o systemd o reiniciou automaticamente
(`Restart=on-failure`), com um novo PID (117914) e a aplicação totalmente
operacional (`Application startup complete`).

### b) `curl -kI https://localhost` e `curl -I http://localhost`

```bash
curl -kI -X GET https://localhost
```
```
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Date: Fri, 25 Sep 2026 12:41:49 GMT
Content-Type: text/html; charset=utf-8
Content-Length: 1262
Connection: keep-alive
accept-ranges: bytes
last-modified: Thu, 24 Sep 2026 13:25:10 GMT
etag: "e97c310eeb7b106101311cbd77f3a1e3"
```

```bash
curl -I http://localhost
```
```
HTTP/1.1 301 Moved Permanently
Server: nginx/1.24.0 (Ubuntu)
Date: Fri, 25 Sep 2026 12:42:16 GMT
Content-Type: text/html
Content-Length: 178
Connection: keep-alive
Location: https://localhost/
```

### c) `ls -la /var/backups/ufla-shop` após 3 execuções do backup

Comandos (com intervalo de 61s entre cada execução, para evitar colisão de
nome pelo timestamp de minuto):
```bash
sudo systemctl start ufla-shop-backup.service
sleep 61
sudo systemctl start ufla-shop-backup.service
sleep 61
sudo systemctl start ufla-shop-backup.service
```

Saída:
```
total 32
drwxr-xr-x 2 root root 4096 set 25 09:44 .
drwxr-xr-x 3 root root 4096 set 25 08:46 ..
-rw------- 1 root root 1623 set 25 08:46 loja-2026-09-25-0846.sql.gz
-rw------- 1 root root 1622 set 25 08:47 loja-2026-09-25-0847.sql.gz
-rw------- 1 root root 1621 set 25 08:48 loja-2026-09-25-0848.sql.gz
-rw------- 1 root root 1621 set 25 09:42 loja-2026-09-25-0942.sql.gz
-rw------- 1 root root 1625 set 25 09:43 loja-2026-09-25-0943.sql.gz
-rw------- 1 root root 1620 set 25 09:44 loja-2026-09-25-0944.sql.gz
```

Registro no journal:
```bash
journalctl -t backup -n 5 --no-pager
```
```
set 25 08:47:18 thiagopc backup[68704]: arquivo gerado: /var/backups/ufla-shop/loja-2026-09-25-0847.sql.gz (4,0K)
set 25 08:48:47 thiagopc backup[70684]: arquivo gerado: /var/backups/ufla-shop/loja-2026-09-25-0848.sql.gz (4,0K)
set 25 09:42:47 thiagopc backup[131467]: arquivo gerado: /var/backups/ufla-shop/loja-2026-09-25-0942.sql.gz (4,0K)
set 25 09:43:48 thiagopc backup[132019]: arquivo gerado: /var/backups/ufla-shop/loja-2026-09-25-0943.sql.gz (4,0K)
set 25 09:44:49 thiagopc backup[132625]: arquivo gerado: /var/backups/ufla-shop/loja-2026-09-25-0944.sql.gz (4,0K)
```

### d) Prova de idempotência — últimas linhas de duas execuções seguidas do `deploy.sh`

Primeira execução:
```
Executing: /usr/lib/systemd/systemd-sysv-install enable nginx
[2026-09-25T09:38:57-03:00] Habilitando serviço e timer...
[2026-09-25T09:38:58-03:00] Executando healthcheck em /ready...
curl: (7) Failed to connect to 127.0.0.1 port 8000 after 0 ms: Couldn't connect to server
[2026-09-25T09:38:59-03:00] Healthcheck OK na tentativa 2.
```

Segunda execução (mesma máquina, sem erros nem duplicação):
```
Executing: /usr/lib/systemd/systemd-sysv-install enable nginx
[2026-09-25T09:39:21-03:00] Habilitando serviço e timer...
[2026-09-25T09:39:23-03:00] Executando healthcheck em /ready...
curl: (7) Failed to connect to 127.0.0.1 port 8000 after 0 ms: Couldn't connect to server
[2026-09-25T09:39:24-03:00] Healthcheck OK na tentativa 2.
```

A linha `curl: (7) Failed to connect...` é esperada: o healthcheck tenta
conectar enquanto o serviço acabou de ser reiniciado pelo `deploy.sh` e ainda
não subiu completamente; na tentativa seguinte (1s depois) a aplicação já
responde e o script termina com sucesso. As duas execuções produziram o
mesmo resultado, sem falhas nem duplicação de recursos — comprovando a
idempotência do script.

### e) Timer diário ativo

```bash
systemctl list-timers | grep ufla-shop
```
```
Sat 2026-09-26 03:00:00 -03       17h -                                      - ufla-shop-backup.timer         ufla-shop-backup.service
```

```bash
systemctl is-enabled ufla-shop-backup.timer
```
```
enabled
```
