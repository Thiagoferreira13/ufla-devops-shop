# Thiago Ferreira Azevedo

## Parte A — Quem é você

- **GitHub:** @Thiagoferreira13
- **Curso e período:** Ciência da Computação, 8º período
- **Linguagem que você domina melhor:** Java
- **Já usou Linux no dia a dia?** Sim
- **Já usou Docker?** Um pouco
- **O que você espera desta disciplina:** Já esperava que a disciplina fosse de grande valor para minha formação e para o mercado de trabalho, mas após a apresentação do curso essa expectativa aumentou ainda mais. Estou animado para aprender ferramentas e práticas que serão essenciais ao longo da minha carreira.

## Parte B — Diagnóstico DORA do seu último projeto

**Frequência de implantação:**
O projeto foi implantado cerca de uma vez por mês, geralmente no fim de semana, quando eu tinha mais tempo disponível para consolidar as mudanças e subir uma nova versão.

**Lead time para mudanças:**
Em média, levava de 15 a 30 dias entre escrever um trecho de código e ele estar disponível na versão publicada, já que eu acumulava várias alterações antes de fazer o deploy.

**Tempo de restauração:**
Quando algo quebrava, o tempo de correção variava bastante — em média, entre 12 a 24 horas, dependendo da complexidade do bug e de eu conseguir reproduzir o erro localmente com facilidade.

**Taxa de falha em mudanças:**
Aproximadamente 2 em cada 3 implantações apresentavam algum problema, geralmente pequenos bugs de interface ou comportamento inesperado em casos que eu não tinha testado antes de subir, o que fazia sentido, já que cada deploy carregava um mês inteiro de alterações acumuladas, aumentando a chance de algo passar despercebido.

**Análise:**
A pior métrica foi o lead time para mudanças. Isso acontecia principalmente porque eu não tinha um fluxo de deploy automatizado nem o hábito de subir alterações pequenas e frequentes, eu preferia juntar várias mudanças e publicar tudo de uma vez, o que aumentava o tempo entre escrever o código e ele realmente estar disponível. Além disso, esse acúmulo tornava mais difícil identificar qual mudança específica havia causado um problema quando ele surgia, já que, ao testar a nova versão, eu me deparava com várias coisas para corrigir ao mesmo tempo, tornando o processo de depuração mais demorado e confuso.