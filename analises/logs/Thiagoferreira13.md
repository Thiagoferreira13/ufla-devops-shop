# Analise de access.log -- Thiago Ferreira Azevedo (@Thiagoferreira13)

**Linhas analisadas:** 516866 dados/access.log

## 1. Volume e falha
```bash
wc -l dados/access.log

awk '$9 >= 400 && $9 < 500' dados/access.log | wc -l

awk '$9 >= 500 && $9 < 600' dados/access.log | wc -l

➜ echo "scale=4; ((6162 + 11749) / 516866) * 100" | bc
```
```
516866 dados/access.log

6162

11749

3.4600
```
**Leitura:** O log tem 516.866 requisicoes no total. Delas, 6.162 falharam com erro 4xx e 11.749 falharam com erro 5xx, somando 17.911 falhas, cerca de 3,46% do trafego total. A taxa de falha parece baixa isoladamente, mas ha quase o dobro de erros 5xx em relacao a 4xx. Isso indica que a maior parte das falhas vem do proprio servidor e que vale investigar a estabilidade da aplicacao.

## 2. Os 10 IPs mais frequentes
```bash
# 10 IPs mais frequentes
awk '{print $1}' dados/access.log | sort | uniq -c | sort -rn | head -10

# O que o IP mais frequente estava pedindo
grep '^203.0.113.47 ' dados/access.log | awk '{print $7}' | sort | uniq -c | sort -rn | head

# User-agent desse IP
grep '^203.0.113.47 ' dados/access.log | cut -d'"' -f6 | sort | uniq -c | sort -rn

# Ritmo: requisicoes desse IP por hora
grep '^203.0.113.47 ' dados/access.log | awk '{print $4}' | cut -d: -f2 | sort | uniq -c
```
```
88400 203.0.113.47
   1788 192.0.2.245
   1772 192.0.2.171
   1771 192.0.2.81
   1771 192.0.2.225
   1771 192.0.2.16
   1767 192.0.2.138
   1762 192.0.2.222
   1757 192.0.2.45
   1753 192.0.2.166

22224 /api/busca?q=mochila
22161 /api/busca?q=tenis
22090 /api/busca?q=camiseta
21925 /api/busca?q=fone

88400 curl/8.5.0

30940 22
57460 23
```
**Leitura:** O IP `203.0.113.47` chama mais atenção porque, além do alto volume, apresenta um padrão diferente dos demais: todas as requisições usam curl/8.5.0, estão concentradas entre 22h e 23h e repetem poucas consultas ao endpoint de busca milhares de vezes. Esse comportamento indica provável atividade automatizada.

## 3. O endpoint quebrado
```bash
# Caminho com mais erro 500
awk '$9 == 500 {print $7}' dados/access.log | sort | uniq -c | sort -rn | head -5

# Total de requisicoes desse caminho
grep -c -F '/api/relatorio/gerar' dados/access.log
```
```
3620 /api/relatorio/gerar
 228 /
 167 /api/produtos
 160 /produtos
 150 /produtos/detalhe

10400
```
**Leitura:** O endpoint `/api/relatorio/gerar` concentra a grande maioria dos erros 500, muito a frente do segundo colocado. Comparando com o total de requisicoes que esse caminho recebeu (10.400), a taxa de falha e de aproximadamente 34,8%. Isso indicca um endpoint estruturalmente instavel.

## 4. A hora do pico
```bash
awk '{print $4}' dados/access.log | cut -d: -f2 | sort | uniq -c | sort -rn
```
```
68535 23
43979 22
32529 15
32526 11
31895 12
31225 14
30886 16
30869 10
29952 13
28575 17
27621 09
25996 18
22807 19
19519 08
18860 20
15577 21
 9759 07
 3904 06
 3262 00
 1967 01
 1844 05
 1810 02
 1498 04
 1471 03
```
**Leitura:** O pico de trafego acontece as 23h, com 68.535 requisicoes, seguido de perto pelas 22h, com 43.979. Essas duas horas somadas ja representam quase 22% de todo o trafego do dia. É exatamente o mesmo horario da rajada do IP suspeito identificado na pergunta 2.

## 5. Alguém batendo na porta
```bash
# Caminhos sensiveis mais tentados
awk '{print $7}' dados/access.log | grep -E '/admin|\.env|\.git|wp-login|phpmyadmin' | sort | uniq -c | sort -rn

# Quantidade de IPs distintos tentando
grep -E '/admin|\.env|\.git|wp-login|phpmyadmin' dados/access.log | awk '{print $1}' | sort -u | wc -l

# O que o servidor respondeu
grep -E '/admin|\.env|\.git|wp-login|phpmyadmin' dados/access.log | awk '{print $9}' | sort | uniq -c
```
```
382 /admin/login
368 /wp-login.php
356 /.git/config
343 /.env
318 /phpmyadmin/index.php
313 /admin

2

2080 404
```
**Leitura:** Ha 2.080 tentativas de acesso a caminhos sensiveis (admin, .env, .git, wp-login, phpmyadmin), partindo de apenas 2 IPs distintos, um numero baixo de origem para um volume alto de tentativas, o que reforça a hipotese de varredura automatizada em busca de vulnerabilidades. Todas as 2.080 tentativas resultaram em 404, ou seja, nenhuma delas teve sucesso.

## Conclusao: minha primeira acao como operador de plantao

Se eu fosse o operador de plantao nesta madrugada, minha primeira acao seria bloquear o IP `203.0.113.47` no firewall ou no proprio Nginx. Os dados mostram que ele e o principal responsavel pelo pico de trafego do servidor (22h-23h), respondendo sozinho por mais requisicoes que os proximos 130 IPs somados, usando um user-agent de automacao (`curl`) e fazendo buscas repetitivas em loop. Bloquear esse IP provavelmente reduziria a carga geral do servidor de forma imediata, o que tambem ajudaria a aliviar o endpoint `/api/relatorio/gerar`, que ja falha em 34,8% das chamadas mesmo sem essa carga extra. Em paralelo, eu escalaria para o time de desenvolvimento a instabilidade desse endpoint especifico, ja que sua taxa de falha e alta demais.