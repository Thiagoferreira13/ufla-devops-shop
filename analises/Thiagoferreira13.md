# Autopsia: Amazon S3 Service Disruption — US-EAST-1 (28/02/2017)

**Autor:** Thiago Ferreira Azevedo (@Thiagoferreira13)
**Fonte primaria:** https://aws.amazon.com/pt/message/41926/
**Data de acesso:** 27/08/2026

## 1. O que aconteceu

Em 28 de fevereiro de 2017, às 9h37 (horário do Pacífico), um funcionário autorizado da Amazon executou um comando de rotina, seguindo um playbook estabelecido, para remover um pequeno número de servidores de um subsistema de cobrança do S3. Um dos parâmetros do comando foi digitado errado, e um número muito maior de servidores foi removido, atingindo também dois outros subsistemas essenciais (índice e alocação de armazenamento), que precisaram ser reiniciados por completo. Enquanto isso, o S3 ficou incapaz de atender requisições, e outros serviços da AWS que dependiam dele (EC2, EBS, Lambda, o próprio painel de status) também foram afetados. O subsistema de índice voltou a funcionar parcialmente às 12h26 e totalmente às 13h18. O de alocação (placement) só finalizou a recuperação às 13h54, quase 4h17 de indisponibilidade total.

## 2. Qual das Três Vias falhou

A falha principal está na **Primeira Via, Fluxo**.

A Primeira Via busca que mudanças avancem em lotes pequenos, com proteções que impeçam um defeito de se propagar adiante no processo. Aqui, a operação deveria remover "a small number of servers", mas o comando teve um parâmetro incorreto e nada no fluxo impediu que uma remoção muito maior do que o planejado fosse executada. Não havia barreira automática checando se a quantidade de capacidade removida ultrapassava um limite seguro. O próprio relatório confirma isso ao descrever a correção pós-incidente: a ferramenta passou a impedir remoções que levassem qualquer subsistema abaixo da capacidade mínima necessária. Ou seja, o defeito (erro de digitação) atravessou o processo inteiro sem nenhum ponto de checagem que o interceptasse antes de causar dano em produção.

## 3. Quais métricas DORA teriam denunciado antes

A métrica mais reveladora aqui é o **Tempo de Restauração**, mas não pelo valor do próprio incidente, e sim porque o relatório expõe uma informação anterior a ele: a Amazon **não reiniciava por completo os subsistemas de índice e placement havia muitos anos** nas regiões maiores. Isso significa que o procedimento de recuperação nunca havia sido exercitado em escala real antes do incidente. Um tempo de restauração desconhecido ou nunca testado é, na prática, um sinal de risco: a organização não sabia quanto tempo levaria para se recuperar de uma falha grave, porque nunca havia precisado, ou testado, esse cenário. Isso é diferente de dizer "o tempo de restauração foi ruim". O dado que já existia antes do incidente era a ausência de testes de recuperação em produção, e é esse vazio que antecipava o risco.

A **Taxa de Falha em Mudanças** também seria reveladora: o comando usava um playbook estabelecido, ou seja, uma operação de rotina, não uma mudança excepcional. Se essa era uma operação recorrente e mesmo assim não tinha proteção automática contra entradas incorretas, isso sugere que a taxa de falha desse tipo específico de mudança operacional provavelmente já não era monitorada com rigor suficiente para motivar a criação de uma salvaguarda antes do incidente.

## 4. Qual prática do semestre teria evitado, e em que semana

A prática mais direta é o **provisionamento de infraestrutura como código com Terraform**, tratado na **semana 14**. Uma operação de remoção de capacidade expressa como código (declarativo, versionado, revisável) permite validação antes da execução, por exemplo, checar programaticamente que a quantidade de servidores a remover não ultrapassa um teto seguro, algo que o comando manual, digitado diretamente, não garantia. É exatamente o tipo de salvaguarda que a Amazon implementou depois do incidente ("added safeguards to prevent capacity from being removed when it will take any subsystem below its minimum required capacity level"), só que como reação, não como prevenção. Com IaC, esse tipo de verificação nasce no próprio código da mudança, antes de qualquer execução em produção.

## 5. A cultura do relatório: generativa ou patológica?

A cultura é **generativa**. O relatório não atribui a causa raiz ao erro humano isoladamente. Ele descreve o comando incorreto como o gatilho, mas concentra a maior parte do texto nas falhas estruturais que permitiram que esse gatilho causasse tanto dano, e nas mudanças de processo e ferramenta feitas em resposta. Isso fica explícito no trecho:

> "We build our systems with the assumption that things will occasionally fail"

Essa frase mostra uma cultura que trata falha como evento esperado do sistema, não como desvio de um indivíduo, típico da tipologia generativa de Westrum, em que a organização busca informação e reprojeta o sistema em vez de buscar um culpado. O relatório reforça isso ao listar ações concretas de melhoria (ferramenta modificada, auditoria de outras ferramentas, reprioridade de trabalho de particionamento) em vez de medidas disciplinares.