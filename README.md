# Projeto DotGroup - DevOps Teste Técnico

🚀 Este projeto mostra como estruturar uma aplicação PHP containerizada, rodando em ECS Fargate com CI/CD automatizado, infraestrutura declarativa em Terraform e observabilidade completa.

---

## Etapa 1: Containerização da Aplicação

### Objetivo
Criar um **Dockerfile otimizado e seguro** para a aplicação PHP fornecida.

### Decisões Técnicas
1. **Multi-stage build**:
   - Utilizei uma imagem `composer:2` como stage de build para instalar dependências PHP sem incluir ferramentas de desenvolvimento no runtime final.
   - Isso reduz o tamanho da imagem final e aumenta a segurança.

2. **Imagem base oficial PHP**:
   - O stage final utiliza `php:8.2-cli` oficial, garantindo compatibilidade e manutenção oficial de segurança.

3. **Execução com usuário não-root**:
   - Criei um usuário `adminuser` para rodar a aplicação, evitando privilégios de root dentro do container.

4. **Estrutura de pastas**:
   - O diretório `/app` contém o código-fonte.
   - A pasta `/app/data` é criada para armazenar o banco SQLite, com permissões corretas para o usuário não-root.

5. **Porta e comando de execução**:
   - Aplicação exposta na porta `8080`.
   - Executa `php -S 0.0.0.0:8080 src/index.php` para iniciar o servidor interno do PHP.

---

## Etapa 2: Pipeline de Integração Contínua (CI)

### Workflow GitHub Actions
- Disparado em `push` para a branch `main`;
- Utilizando ubuntu-latest como runner;
- Passos executados:

1. **Checkout do código**  
   - Utilizando `actions/checkout@v4`.

2. **Login no Docker Hub**  
   - Utilizando secrets `DOCKER_HUB_USERNAME` e `DOCKER_HUB_ACCESS_TOKEN`.

3. **Setup Terraform**
   - Inicia o ambiente do Terraform.

4. **Build da imagem Docker**  
   - Tag baseada no SHA do commit: `${GITHUB_SHA:0:7}`.
   - Garante rastreabilidade da imagem para cada commit.

5. **Scan de vulnerabilidades**  
   - `docker scout` analisa CVEs críticos e altos.
   - Gera relatório e recomendação em formato SARIF enviado para o GitHub Security.

6. **Push da imagem Docker**  
   - Publicação da imagem no Docker Hub para uso em produção/CD.

7. **Update Task Definition via Terraform** 
   - O arquivo update-task.tf permite atualizar a definição da tarefa no ECS com a nova imagem da aplicação.
   - Executa `terraform apply -var "image_tag=${{ env.IMAGE_TAG }}"`.

8. **Update ECS Service**  
   - Busca a ultima revisão e executa `aws ecs update-service --force-new-deployment` para que o serviço ECS pegue a nova imagem.

---

## Etapa 3: Infraestrutura como Código (IaC) e CD

### Justificativa da escolha
- **Escolhi ECS Fargate** ao invés de EKS por:

  - Experiência prévia com ECS em ambientes de produção. 
  - Menor complexidade operacional.
  - Gerenciamento automático de infraestrutura (não precisa de nodes EC2).
  - Fácil integração com ALB, Target Groups e Auto Scaling.

### Estrutura Terraform
- **Arquivos principais**:
  - `network.tf` → VPC, subnets, IGW, NAT Gateway, Route Tables
  - `ecs.tf` → ECS Cluster, Task Definition, Service
  - `load-balancer.tf` → ALB, Target Group e Listener
  - `iam-roles.tf` → Roles e Policies ECS
  - `output.tf` → DNS do ALB, nomes do cluster e service
  - `main.tf` → Provider AWS e configurações globais
  - `update-task.tf` → Atualiza a Task Definition com a nova versão da Imagem do projeto

### Auto Scaling
- Configuração de Target Tracking baseado em **CPU média**:
  - `min_capacity = 1`, `max_capacity = 2`.
  - Mantém performance da aplicação sem desperdício de recursos.

### Load Balancer
- Configurado Application Load Balancer.
- Na ausência de um domínio próprio, a aplicação foi publicada utilizando o mapeamento da porta 80 → 8080.
- Em um ambiente de produção, a recomendação seria habilitar HTTPS (porta 443) com certificado gerenciado pelo AWS ACM, além de configurar regras de roteamento no ALB (ex.: baseadas em cabeçalho Host) para suportar múltiplos serviços sob o mesmo balanceador.

### Deploy Contínuo (CD)
- O pipeline de CI/CD executa o build e push da imagem Docker.
- Em seguida, aplica a nova Task Definition via Terraform.
- O ECS Service é atualizado automaticamente para executar a nova versão da aplicação.

---

## Etapa 4: Estratégia de Observabilidade

### Stack recomendada
- **Prometheus** → Coleta de métricas do container e serviço.
- **Grafana** → Dashboard para visualização das métricas.
- **AWS CloudWatch** → Métricas nativas do ECS/Fargate.
- **Grafana Loki** → Consulta avançada de Logs da aplicação (Export do CloudWatch p/ Loki)
- **Grafana Tempo e OpenTelemetry** → Coleta e armazenamento de rastreamento distribuído (traces) de requisições da aplicação. 

### Estratégia de Implantação
Três opções para hospedar a stack de observabilidade:  

1. **ECS Services separados** → Cada ferramenta em uma Task Definition. Escalável e alinhado a microsserviços, porém com maior custo.  
2. **EC2 centralizada** → Uma instância rodando Docker Compose. Mais barato, mas exige manutenção manual.  
3. **Sidecars na aplicação** → Agentes leves (ex.: OpenTelemetry) junto à Task da aplicação. Simples, mas acoplado.  

### Métricas principais
1. **CPU Utilization (ECS Task)** → Indica carga da aplicação.
2. **Memory Utilization (ECS Task)** → Evita que containers fiquem sem memória.
3. **Request Count / Error Rate (via métricas do HTTP com Dashboardno Grafana)** → Monitora saúde da aplicação e erros HTTP.

### Justificativa
- Permite identificar rapidamente problemas de performance e escalabilidade.
- Possibilita integração com alertas em Slack ou Teams.
- Ajuda na análise de capacidade e planejamento de recursos.
