# Etapa 4 — Criação do cluster Kubernetes com kind

## 1. Objetivo

Preparar e validar um cluster Kubernetes local utilizando kind (Kubernetes IN Docker), criando a infraestrutura necessária para executar posteriormente o OWASP Juice Shop no Kubernetes.

## 2. Configuração do cluster

Configuração recuperada do commit `3209aaf`:

| Propriedade | Valor |
|---|---|
| Tipo | `Cluster` |
| API de configuração | `kind.x-k8s.io/v1alpha4` |
| Nome do cluster | `juiceshop-local` |
| Quantidade de nós | 1 |
| Função do nó | `control-plane` |

Conteúdo versionado em `kind-config.yaml`:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: juiceshop-local
nodes:
  - role: control-plane
```

## 3. Atividades registradas nas evidências

As capturas da etapa registram atividades relacionadas a:

- Verificação do ambiente Docker.
- Instalação e verificação de `kubectl` e kind.
- Preparação e versionamento da configuração do cluster.
- Criação do cluster `juiceshop-local`.
- Verificação dos nós Kubernetes.
- Verificação dos contêineres do kind no Docker.
- Consulta dos pods do sistema.
- Inspeção do nó Kubernetes.
- Criação e remoção de um deployment de teste em namespace.
- Consulta dos logs do deployment de teste.
- Verificação do contexto kubeconfig.
- Destruição e recriação do cluster.
- Validação após a recriação.

As atividades acima são descritas com base nas capturas identificadas para esta etapa. Não representam uma nova execução dos comandos.

## 4. Evidências

As 17 capturas identificadas para esta etapa estão em `evidencias/`:

1. `E4-01-ambiente-docker.png`
2. `E4-02-instalacao-kubectl-kind.png`
3. `E4-03-configuracao-kind.png`
4. `E4-04-config-kind-versionada.png`
5. `E4-05-criacao-cluster-kind.png`
6. `E4-06-kubectl-get-nodes-ready.png`
7. `E4-07-nos-kind-containers-docker.png`
8. `E4-08-pods-sistema-running.png`
9. `E4-09-describe-node.png`
10. `E4-10-namespace-deploy-teste.png`
11. `E4-11-logs-deploy-teste.png`
12. `E4-12-deploy-teste-removido.png`
13. `E4-13-kubeconfig-context.png`
14. `E4-14-cluster-destruido.png`
15. `E4-15_16-docker-prova-sem-vm.png`
16. `E4-15-cluster-recriado-config.png`
17. `E4-17-validacao-pos-recriacao.png`

## 5. Decisões técnicas

- Utilizar kind para executar um cluster Kubernetes local.
- Utilizar o Docker como infraestrutura dos nós do cluster.
- Manter a configuração do cluster em arquivo YAML versionado.
- Utilizar um único nó com função `control-plane` nesta configuração.
- Validar a criação, o estado e a recriação do cluster por meio das ferramentas Kubernetes.

## 6. Referência no histórico Git

- Commit: `3209aaf`.
- Data: 27/10/2026.
- Mensagem: `feat: adiciona configuracao do cluster kind`.
- Arquivo adicionado: `kind-config.yaml`.
