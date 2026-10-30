# Etapa 5 — Implantação do Juice Shop no Kubernetes

## 1. Objetivo

Implantar o OWASP Juice Shop no cluster Kubernetes local criado com kind, utilizando manifestos versionados para controlar os Pods, a quantidade de réplicas e o acesso interno à aplicação.

## 2. Arquivos de configuração

Os três manifestos foram adicionados ao repositório no commit `6b69fee`:

- `k8s/namespace.yaml`
- `k8s/deployment.yaml`
- `k8s/service.yaml`

## 3. Namespace

Foi criado o namespace dedicado `juiceshop`, com a identificação:

`app.kubernetes.io/name: juice-shop`

O objetivo é manter os recursos da aplicação organizados em um namespace próprio.

## 4. Deployment

Configuração recuperada do manifesto versionado:

| Propriedade | Valor |
|---|---|
| Nome | `juice-shop` |
| Namespace | `juiceshop` |
| Imagem | `bkimminich/juice-shop:v20.3.0` |
| Réplicas desejadas | 2 |
| Política de imagem | `IfNotPresent` |
| Estratégia | `RollingUpdate` |
| `maxSurge` | 1 |
| `maxUnavailable` | 0 |
| Porta do contêiner | TCP 3000 |

### 4.1 Verificações de saúde

O Deployment utiliza duas verificações HTTP:

**Readiness Probe**

- Caminho: `/`.
- Porta: `http`.
- Atraso inicial: 10 segundos.
- Intervalo: 5 segundos.
- Timeout: 3 segundos.
- Limite de falhas: 6.

**Liveness Probe**

- Caminho: `/`.
- Porta: `http`.
- Atraso inicial: 30 segundos.
- Intervalo: 10 segundos.
- Timeout: 3 segundos.
- Limite de falhas: 6.

A readiness probe controla quando o Pod está pronto para receber tráfego. A liveness probe permite que o Kubernetes reinicie um contêiner que permaneça sem responder.

### 4.2 Recursos

| Tipo | CPU | Memória |
|---|---:|---:|
| Requests | 200m | 384Mi |
| Limits | 500m | 768Mi |

Os requests representam os recursos solicitados para o agendamento. Os limits definem os limites máximos configurados para o contêiner.

## 5. Service

Foi criado um Service chamado `juice-shop`, no namespace `juiceshop`.

Configurações:

- Tipo: `ClusterIP`.
- Porta do serviço: TCP 3000.
- Porta de destino: `http` (porta nomeada no contêiner).
- Seletor: `app: juice-shop`.

O tipo `ClusterIP` mantém o serviço acessível internamente pelo cluster. Não foi configurado `NodePort` neste manifesto.

## 6. Atividades e validações registradas

As evidências da etapa documentam:

- Verificação do ambiente e dos arquivos.
- Preparação e validação dos manifestos.
- Versionamento dos arquivos Kubernetes.
- Carregamento da imagem no kind.
- Criação do namespace.
- Aplicação do Deployment e do Service.
- Verificação dos Pods e do Service.
- Acesso ao Juice Shop pelo Kubernetes.
- Recuperação automática de Pod.
- Escalonamento para três réplicas e retorno para duas.
- Carregamento de imagem alternativa.
- Rolling update para a versão `v20.2.0`.
- Rollback para a versão `v20.3.0`.
- Validação final do Kubernetes e do acesso HTTP.
- Verificação do funcionamento do Kubernetes sem o Compose.
- Configuração de probes e recursos.
- Confirmação do Service como `ClusterIP`.

As atividades são descritas com base nas evidências identificadas. Este documento não representa uma nova execução dos testes.

## 7. Evidências

As 22 capturas físicas identificadas para esta etapa estão em `evidencias/`:

1. `E5-01-validacao-ambiente.png`
2. `E5-02-verificacao-imagem-e-arquivos.png`
3. `E5-03-preparacao-manifestos-e-tags.png`
4. `E5-04-validacao-manifestos.png`
5. `E5-05-manifestos-versionados.png`
6. `E5-06-imagem-carregada-no-kind.png`
7. `E5-07-namespace-criado.png`
8. `E5-08-deployment-e-service-aplicados.png`
9. `E5-09-validacao-pods-e-service.png`
10. `E5-10-juiceshop-acesso-kubernetes.png`
11. `E5-11-recuperacao-automatica-pod.png`
12. `E5-12-escalonamento-3-replicas.png`
13. `E5-13-retorno-2-replicas.png`
14. `E5-14-imagem-alternativa-carregada.png`
15. `E5-15-estado-antes-rolling-update.png`
16. `E5-16-rolling-update-v20.2.0.png`
17. `E5-17-rollback-v20.3.0.png`
18. `E5-18-validacao-final-kubernetes.png`
19. `E5-19-validacao-acesso-http.png`
20. `E5-20-compose-antigo-parado_E5-21-kubernetes-funcionando-sem-compose.png`
21. `E5-22-deployment-probes-e-recursos.png`
22. `E5-23-service-clusterip.png`

A captura de número 20 reúne os registros identificados como E5-20 e E5-21 em um único arquivo físico.

## 8. Decisões técnicas

- Utilizar Deployment para controlar a quantidade desejada de réplicas.
- Utilizar duas réplicas como configuração padrão.
- Utilizar probes HTTP para verificar disponibilidade e funcionamento.
- Definir requests e limits para CPU e memória.
- Utilizar Service `ClusterIP` para manter o acesso interno.
- Manter os manifestos versionados para permitir reprodução e revisão.

## 9. Referência no histórico Git

- Commit: `6b69fee`.
- Data: 28/10/2026.
- Mensagem: `feat: adiciona manifestos Kubernetes do Juice Shop`.
- Arquivos adicionados: `deployment.yaml`, `namespace.yaml` e `service.yaml`.
