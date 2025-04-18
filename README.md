# Objetivo

Um laboratório de integração contínua e entrega contínua (CI/CD) baseado em GitOps utilizando ArgoCD, com o padrão "App of Apps", em uma arquitetura multi-cluster para simular cenários de desenvolvimento, produção e gestão de recursos Kubernetes/applicação.

- Utilizar **ArgoCD** para deploy e sincronização.
- Git como **fonte de verdade**
- Organizar os manifestos usando o **padrão App-of-Apps**
- Clusters separados para cada ambiente (prod e não-prod) e cluster de gerenciamento.
- Todos os recursos gerenciados pelo argoCD e versionados via git, onde fizer sentido.

_Esse projeto não aborda parte de CI, cada repositório de aplicação cobre essa etapa por si só._

## Diagramas

### Organização Multi-cluster

![Organização MultiCluster](./assets/argocd-clusters.png)

- 1 cluster para gerenciamento onde fica implantado o ArgoCD
- 1 cluster representando cada ambiente, embora no diagrama esteja representado o EKS, o argoCD é agnostico a isso.

### Organização da aplicação

![Organização da aplicação no cluster](./assets/organizacao-project-argo.png)

- Project para cada ambiente
  - app-of-apps application : Gerência as aplicações e seus recursos próprios, como: Deployment, Service, HPA, Configmap, PV, PVC, etc.
  - app-of-apps shared: Gerência recursos compartilhados entre os serviços ou configurações default, como: Ingress-controller, limit-range, namespace, etc.
  - app-of-apps infra: Gerência recursos e CRD's de administração ou que as aplicações dependem como: cert-manager, CRD ingress, Stack de observabilidade, etc.
  - A idéia é que tudo o possível seja gerenciado pelo argo e versionado, exceto dados sensíveis como os secrets, configmaps, etc.

### Fluxo de deploy - Visão OPS

![Fluxo de deploy](./assets/fluxo-deploy.png)

- Esse projeto não se propõe a abordar pipelines de CI, ou seja, testes, build, gitflow, etc, isso está coberto pelos repositórios das aplicações.
- Durante as fases de SYNC são enviados alertas de status para canal Telegram.
- IAC também está coberto pelo repositório de IAC

### Fluxo de CICD - Visão Gitflow

![Fluxo CICD](./assets/flow-cicd.png)

## Ordem de Deploy

- app project
- app of apps
  - infra.yaml
  - shared.yaml
  - Manisfestos sensíveis não versionados (caso necessário).
  - application.yaml

## Repositórios

### Código

- [Frontend](https://github.com/Adenilson365/devopslabs01-frontend)
- [Api-Catalogo](https://github.com/Adenilson365/devopslabs01-catalogo)
- [Api-Images](https://github.com/Adenilson365/devopslabs01-api-images)

### OPS

- [Frontend](https://github.com/Adenilson365/devopslabas01-ops-frontend)
- [Api-Catalogo](https://github.com/Adenilson365/devopslabs01-ops-catalogo)
- [Api-Images](https://github.com/Adenilson365/devopslabs01-ops-api-images)

### IAC

- [Terraform para GCP](https://github.com/Adenilson365/devopslabs01-iac)

### ArgoCD

- [Principal - App-of-Apps (Este mesmo)](https://github.com/Adenilson365/argocd-lab)

- [Manifestos compartilhados - Shared](https://github.com/Adenilson365/devops-labs01-config)

## Como reproduzir:

### Requisitos:

- Cloud CLI
- 2 ou 3 Cluster Kubernetes em cloud

### Infraestrutura:

- Requisitos: 3 cluster Kubernetes, você pode criar os clusters na mão, ou aplicar 1 dos meus labs de terraform:
- [Usando GKE na GCP](https://github.com/Adenilson365/devopslabs01-iac)
- [Usando EKS na AWS](https://github.com/Adenilson365/tf-labs01-aws-k8s)
- Se optar por rodar GKE - o script install.sh contém os comandos para atualizar o kubeconfig e instalar o argo.
  🚨 **OPERAR EM NUVÉM GERA CUSTOS, SEJA CUIDADOSO**

### DNS - Utilizo o cloud DNS do GCP

- Para esse laboratório utilizo domínio próprio, e uso o cloud dns do GCP para criar os subdomínios para cada itém.
- Após aplicar todos os manifestos, é necessário atualizar os registros A da sua zona DNS para apontar para os IPs dos
  load balancing provisionados.
- Para usar em conjunto com Let's Encrypt, veja como configurar na documentação de referência.
  - Nesse Lab você pode ter um exemplo de configuração [link](https://github.com/Adenilson365/devopslabs01-catalogo/blob/main/README.md)

### Aplicação

- Cada repositório tem suas dependências e configurações específicas que precisam ser aplicadas.

### Implantar

- Após satisfazer os requisitos anteriores, basta aplicar o deploy na ordem:
- app project
- app of apps
  - infra.yaml
  - shared.yaml
  - Manisfestos sensíveis não versionados (caso necessário).
  - application.yaml

### Documentação de referência:

- [ArgoCD](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [Let's Encrypt](https://letsencrypt.org/pt-br/docs/)
- [GKE](https://cloud.google.com/kubernetes-engine/docs?hl=pt-br)
- [Argocd Hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/)

### Ingress-Controller com Nginx e Let's Encrypt

- O ArgoCD-server serve dois protolocos na mesma porta HTTPS e GRPC.
  - HTTPS para console WEB
  - GRPC para argocd-cli
- Cada ingress-controller pode atender apenas um protocolo por vez, para isso é necessário 2 ingress ou 1 ingress mas o nginx perde algumas funcionalidades.
  Basicamente com 1 ingress, o nginx vai apenas encaminhar o tráfego sem inspecionar, reescrever headers ou coletar métricas detalhadas, deixando que isso seja feito no final e resolvido pelo argocd-server. Dessa forma é possível fazer o login tanto via WEB quando CLI com o mesmo domínio.

- Instalação do let's encrypt segue o mesmo padrão.
- Ingress-Nginx - Instale com a flag: enable-ssl-passthrough
  `YAML
    #Via helm adicione:
    controller.extraArgs.enable-ssl-passthrough=true
    #Via appliccation de helm no argocd 
    parameters:
    - name: controller.extraArgs.enable-ssl-passthrough
      value: ""
` - Adicione as anottations abaixo:
  `YAML
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
` - Secret precisa ter o nome esperado pelo argocd
  `YAML
  tls:
    - hosts:
        - argo.konzelmann.com.br
        secretName: argocd-server-tls
`
  [Documentação de referência](https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/)

### Alertas para o Telegram

- Crie seu chat com bot_father [Veja esse guia](https://apidog.com/pt/blog/beginners-guide-to-telegram-bot-api/?utm_source=google_dsa&utm_medium=g&utm_campaign=22400621269&utm_content=174661787022&utm_term=&gad_source=1&gad_campaignid=22400621269&gbraid=0AAAAA-gKXrBQfRh0AtC-0xXtRSJs0cCAn&gclid=CjwKCAjw8IfABhBXEiwAxRHlsD8ZKEzv2dZgsva5HLKUXqsVbUv5nLSUjvMFIxYQjY4oxbKcMO5YKBoCI1YQAvD_BwE)
- Pegue o token do seu bot
- Pegue o id do seu chat:

```
https://api.telegram.org/bot<Idbot>/getUpdates
```

- Comando curl

```shell
 curl -s -X POST https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage \
              -d chat_id=${TELEGRAM_CHAT_ID} \
              -d text="Sua Mensagem"
```

- Alertas de Sync Recebidos

![Telegram-msg](./assets/telegram.png)

## 🔥 Próximos passos planejados:

- 🚧 Integração com Keycloak para autenticação SSO (em estudo).
- 🚧 Adição de argo-rollouts para estratégias avançadas de deploy.

## 📚 Conceitos Aplicados no Projeto

## 📚 Conceitos Aplicados no Projeto

| Conceito                             | Descrição                                                                                                                           |
| ------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------- |
| **GitOps**                           | Git como fonte de verdade; mudanças versionadas disparam deploys automáticos no ambiente.                                           |
| **Gitflow**                          | Estrutura de branches para controlar o ciclo de vida do código, evitando alterações diretas na branch principal.                    |
| **App of Apps**                      | Application raiz do ArgoCD que gerencia múltiplas applications filhas, cada uma responsável por um serviço ou conjunto de recursos. |
| **ArgoCD**                           | Ferramenta de Continuous Delivery que sincroniza o estado do cluster com os manifestos versionados no Git.                          |
| **Multi-cluster**                    | Arquitetura que utiliza múltiplos clusters Kubernetes, separados por função (gerenciamento, produção, desenvolvimento).             |
| **Helm via ArgoCD**                  | Utilização de Helm Charts gerenciados por ArgoCD para parametrizar e versionar aplicações de forma reutilizável.                    |
| **Infraestrutura como Código (IaC)** | Provisionamento de recursos de nuvem e clusters Kubernetes usando Terraform.                                                        |
| **DNS com Cloud DNS (GCP)**          | Gerenciamento de subdomínios e registros DNS diretamente via Cloud DNS para expor serviços nos clusters.                            |
| **Let's Encrypt + TLS**              | Emissão automática de certificados SSL via cert-manager, com uso de NGINX e SSL passthrough para suportar HTTPS e GRPC.             |
| **Notificações no Telegram**         | Integração com a API do Telegram para envio de mensagens de status do deploy durante o processo de sincronização.                   |
| **Gerenciamento de Secrets**         | Dados sensíveis, como senhas e tokens, não são versionados com os manifestos e devem ser tratados separadamente.                    |
| **Separação de ambientes**           | Ambientes isolados por cluster ou namespace, com manifestos e pipelines independentes para cada estágio.                            |
| **Ordem de Deploy**                  | Estratégia em camadas: infraestrutura → recursos compartilhados → aplicações, respeitando dependências.                             |
| **SSO com Keycloak**                 | Planejamento de autenticação centralizada utilizando Keycloak como Identity Provider (em estudo).                                   |
