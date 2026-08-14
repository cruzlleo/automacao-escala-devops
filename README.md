# Automação em Escala e Migração Sem Downtime — Case Study

> Case study técnico. Ambiente e dados anonimizados/generalizados por confidencialidade — o foco é a engenharia aplicada, não detalhes de nenhuma organização específica.

## Contexto 1 — Deploy em massa sem acesso administrativo direto

Necessidade de implantar um agente de software (inventário/gestão) em toda uma frota de estações Windows gerenciadas por diretório corporativo, em um cenário onde o acesso administrativo direto ao servidor de diretório não estava disponível via interface gráfica.

## Desafio

- Instalar um agente com privilégio de sistema em centenas de máquinas, sem depender do usuário logado ter permissão de administrador local.
- Fazer isso sem acesso GUI ao console de gestão do diretório.
- Cobrir também máquinas que estivessem temporariamente desligadas ou fora da rede (ex: em férias) sem exigir uma segunda rodada manual.

## Abordagem

Toda a operação foi feita via linha de comando, manipulando diretamente os componentes que a interface gráfica normalmente edita:

1. **Criação de script de inicialização** e de uma tarefa agendada de execução imediata, escritos diretamente nos arquivos de política que o diretório distribui para todas as máquinas — sem passar pela ferramenta de gestão gráfica.
2. **Atualização dos metadados da política** no próprio diretório via chamada administrativa remota, sem RDP, para que as máquinas reconhecessem a nova versão da política a aplicar.
3. **Execução com privilégio de sistema**: a tarefa foi configurada para dispatch automático no próximo ciclo de atualização de política (dentro de ~1h30), instalando o agente como conta de sistema — independente de qual usuário estivesse logado.
4. **Validação remota** antes de considerar concluído: execução de teste em uma máquina de controle confirmando o serviço ativo, sem esperar relatório espontâneo.
5. **Cobertura contínua por design**: por estar vinculada à política no nível raiz do domínio, qualquer máquina que retornasse à rede (ex: após período afastada) recebia o agente automaticamente, sem necessidade de nova campanha manual.

## Contexto 2 — Migração de sistema com zero downtime (blue/green)

Upgrade de duas versões maiores de uma plataforma interna (gestão de ativos de TI), incluindo troca do motor de banco de dados subjacente por uma versão suportada a longo prazo.

## Abordagem

- **Ambiente paralelo ("green")** provisionado do zero ao lado do ambiente em produção ("blue"), sem interromper o sistema em uso.
- **Reconstrução de configuração perdida**: a definição de infraestrutura como código de um dos componentes não estava salva; foi reconstruída inspecionando os containers em execução, sem downtime.
- **Recuperação de credencial de serviço**: uma senha de integração estava armazenada de forma cifrada por mecanismo proprietário da própria aplicação; foi decifrada executando a lógica nativa de descriptografia da aplicação, sem precisar resetar a credencial (o que quebraria a integração em produção até reconfiguração manual).
- **Transferência segura de arquivo de configuração sensível** entre ambientes, evitando que caracteres especiais fossem interpretados incorretamente pelo shell (usando encode/decode).
- **Migração de schema** executada via ferramenta nativa de migração da própria aplicação, cobrindo todas as versões intermediárias automaticamente.
- **Cutover planejado**: ambiente novo colocado em porta separada para validação final, com o ambiente antigo mantido como fallback por um período de segurança antes do corte definitivo.

## O que eu tiraria disso pra próxima vez

- Vale documentar a definição de infraestrutura (IaC) de qualquer stack assim que ela sobe — reconstruir por engenharia reversa funciona, mas custa tempo que poderia ser evitado.
- Automação "sem GUI" via manipulação direta dos artefatos que a interface gráfica edita é uma habilidade que vale a pena desenvolver — nem sempre o acesso administrativo tradicional está disponível.
- Blue/green vale o esforço extra mesmo para sistemas internos "pequenos": o custo de manter o ambiente antigo por alguns dias é muito menor que o risco de um rollback sob pressão.

---

**Stack:** Docker Compose · Active Directory / GPO · impacket · smbclient · PowerShell remoto
