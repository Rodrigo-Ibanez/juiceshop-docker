# Etapa 6 — Nginx Edge, HTTPS e integração com Kubernetes

## 1. Objetivo

Implementar e validar uma camada de entrada independente com Nginx Edge, executada em Docker e conectada à rede do cluster Kubernetes criado com kind.

O objetivo foi centralizar o acesso ao OWASP Juice Shop por meio de um proxy reverso, habilitando HTTPS local, redirecionamento HTTP, cabeçalhos de segurança, limitação de requisições e registros de acesso.

O laboratório é destinado exclusivamente a treinamento. O Juice Shop é deliberadamente vulnerável e não deve receber dados reais, credenciais pessoais ou informações sensíveis.

## 2. Arquitetura implementada

O fluxo validado foi:

```text
Navegador no Windows
        |
        | https://juiceshop.local
        | hosts -> 127.0.0.1
        |
        v
Nginx Edge — Docker
        |
        | Rede Docker kind
        | NodePort 30080
        |
        v
Nó control-plane do kind
        |
        v
Service Kubernetes — NodePort
        |
        | Porta 3000
        |
        v
Deployment juice-shop
        |
        +---- Pod 1
        |
        +---- Pod 2
```

### Componentes registrados

| Componente | Configuração |
|---|---|
| Cluster | `juiceshop-local` |
| Kubernetes | v1.37.0 |
| Namespace | `juiceshop` |
| Deployment | `juice-shop` |
| Réplicas disponíveis | 2/2 |
| Service | NodePort |
| Porta interna do Service | 3000 |
| NodePort | 30080 |
| Imagem | `bkimminich/juice-shop:v20.3.0` |
| Nginx Edge | `nginx:1.28-alpine` |
| Hostname local | `juiceshop.local` |
| Upstream definitivo | `http://juiceshop-local-control-plane:30080` |

Os endereços dos Pods registrados nas capturas são informações históricas. Eles podem mudar quando o cluster for recriado.

## 3. Decisão arquitetural

Foi adotada a alternativa de manter o Nginx Edge independente do cluster, executado em Docker e conectado à rede Docker `kind`.

O Nginx encaminha as requisições para o NodePort do nó control-plane:

`http://juiceshop-local-control-plane:30080`

O nome DNS do nó é utilizado para evitar dependência de um endereço IP fixo.

Essa abordagem permitiu reutilizar o Nginx como ponto de entrada e validar HTTPS, redirecionamento, cabeçalhos de segurança, limitação de requisições e logs sem instalar um Ingress Controller.

A alternativa de utilizar um Ingress Controller não foi adotada porque acrescentaria componentes desnecessários para o escopo deste laboratório.

**Observação histórica:** uma configuração inicial registrou o IP `172.20.0.2` como destino. A configuração definitiva documentada utiliza o nome DNS `juiceshop-local-control-plane`, conforme a documentação consolidada e a validação de reprodução após recriação do cluster.

## 4. HTTPS e redirecionamento

O hostname `juiceshop.local` foi configurado para resolução local pelo arquivo `hosts`, apontando para `127.0.0.1`.

O Nginx Edge recebeu as seguintes responsabilidades:

- Publicar HTTP na porta local 80.
- Publicar HTTPS na porta local 443.
- Redirecionar requisições HTTP para HTTPS com status `301`.
- Utilizar certificado autoassinado para o hostname local.
- Encaminhar as requisições HTTPS ao NodePort do Kubernetes.

O HTTPS foi validado com resposta HTTP 200.

Como o certificado é autoassinado e não foi emitido por uma autoridade certificadora reconhecida pelo navegador, foi observado o aviso de confiança esperado.

O certificado atende ao laboratório local, mas não equivale a um certificado público confiável.

## 5. Configuração de segurança do Nginx

A configuração versionada no commit `99ec228` inclui:

- `server_tokens off`, para ocultar a versão do Nginx nas respostas.
- Protocolos TLS 1.2 e TLS 1.3.
- Cabeçalhos de segurança.
- Limitação de requisições.
- Registros de acesso e de erros.
- Encaminhamento dos cabeçalhos `Host`, `X-Real-IP`, `X-Forwarded-For` e `X-Forwarded-Proto`.

### Cabeçalhos configurados

| Cabeçalho | Valor |
|---|---|
| `Strict-Transport-Security` | `max-age=300` |
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `SAMEORIGIN` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |

Esses cabeçalhos oferecem proteções específicas no acesso à aplicação. Eles não corrigem nem eliminam as vulnerabilidades intencionais do OWASP Juice Shop.

## 6. Limitação de requisições

Foi configurada uma zona de limitação por endereço remoto com os seguintes parâmetros:

- Taxa: 5 requisições por segundo.
- Rajada permitida: 10 requisições.
- Resposta ao exceder o limite: HTTP 429.
- Opção `nodelay` para tratamento da rajada.

No teste registrado, uma sequência de 40 requisições produziu:

| Resposta | Quantidade |
|---|---:|
| HTTP 200 | 24 |
| HTTP 429 | 16 |
| Total | 40 |

Esses números representam o resultado observado naquela execução. Não constituem uma proporção garantida para todas as execuções.

## 7. Logs e correlação de requisições

O Nginx registra acessos em:

`/var/log/nginx/access.log`

E ocorrências relevantes em:

`/var/log/nginx/error.log`

Foi utilizado o marcador:

`E47-CORRELACAO-FINAL`

A requisição com esse marcador foi localizada no log do Nginx e no log da aplicação em um dos Pods.

A ausência do marcador no outro Pod é compatível com a distribuição de requisições entre as réplicas disponíveis.

Durante a investigação, também foram examinados os arquivos internos de log da aplicação, incluindo arquivos no padrão:

`/juice-shop/logs/access.log.DATE`

Esses registros podem não aparecer integralmente em `kubectl logs`, pois parte da saída pode ser direcionada para arquivos internos do contêiner.

## 8. Isolamento e exposição

O Nginx Edge publica as portas locais 80 e 443 vinculadas a `127.0.0.1`.

O Service Kubernetes utiliza NodePort 30080, mas essa porta não foi publicada diretamente no Windows.

As validações registradas indicaram:

- Acesso local à aplicação pelo Nginx Edge.
- HTTPS funcional.
- Redirecionamento HTTP para HTTPS.
- Acesso direto pelo loopback do Windows à porta NodePort não disponível.
- Regras específicas de encaminhamento do Windows removidas.
- Verificação de exposição no roteador registrada nas evidências.

A documentação registra que não havia encaminhamento de portas ou DMZ ativos para o laboratório no roteador durante a validação. Essa informação corresponde ao estado observado e documentado naquele momento; não substitui uma nova conferência do equipamento antes de uma demonstração futura.

## 9. Responsabilidades das tecnologias

| Tecnologia | Responsabilidade nesta etapa |
|---|---|
| Docker | Executar o contêiner Nginx Edge e fornecer a rede compartilhada com o nó do kind. |
| kind | Executar o cluster Kubernetes local usando contêineres Docker como nós. |
| Kubernetes | Gerenciar Pods, réplicas, verificações de saúde e Service do Juice Shop. |
| Nginx | Centralizar a entrada HTTP/HTTPS, terminar TLS, redirecionar HTTP, aplicar cabeçalhos e limitar requisições. |

## 10. Dificuldades e decisões

### Acesso ao NodePort

O NodePort não estava disponível diretamente pelo loopback do Windows. A solução adotada foi conectar o Nginx Edge à rede Docker `kind` e encaminhar as requisições ao NodePort do nó.

### Descoberta do endereço do nó

Inicialmente foi considerada a utilização do IP do contêiner. A configuração definitiva passou a utilizar o nome DNS `juiceshop-local-control-plane`, evitando depender de um IP fixo.

### Certificado autoassinado

O HTTPS funcionou, mas o navegador apresentou aviso de confiança. Esse comportamento é esperado para um certificado autoassinado que não foi confiado pelo sistema.

### Investigação dos logs

Foi necessário localizar os arquivos internos de log da aplicação e correlacionar os registros com os acessos observados no Nginx.

### Reprodução após recriação do cluster

A configuração utiliza o nome DNS do nó do kind como upstream:

`http://juiceshop-local-control-plane:30080`

Para reproduzir o ambiente, o cluster deve ser criado com o nome esperado e o contêiner Nginx deve estar conectado à rede Docker `kind`.

A sintaxe do Nginx pode ser validada com:

```bash
docker exec juice-shop-nginx-edge nginx -t
```

Essa validação confirma a sintaxe da configuração. A comunicação com o upstream também deve ser testada por meio de uma requisição HTTPS à aplicação.

## 11. O que faria diferente

Para tornar a reprodução mais robusta, automatizaria:

- A criação do cluster.
- A conexão do Nginx à rede Docker.
- A verificação de disponibilidade do upstream.
- Os testes de HTTPS e dos cabeçalhos.
- A coleta e correlação dos logs.

Um Ingress Controller poderia ser avaliado caso o laboratório passasse a exigir múltiplas aplicações ou roteamento mais declarativo. Ele não foi necessário para os objetivos desta etapa.

## 12. Limitações e cuidados

- O certificado utilizado é autoassinado.
- O ambiente depende da rede Docker e do nome esperado do nó do kind.
- O proxy reverso, o HTTPS e os cabeçalhos não corrigem as vulnerabilidades intencionais da aplicação.
- O resultado dos testes de limitação de requisições pode variar entre execuções.
- O laboratório deve permanecer local, com dados fictícios e sem credenciais reais.
- Não habilitar encaminhamento de portas, DMZ ou exposição pública sem autorização e avaliação de risco.

## 13. Evidências

As 53 capturas da Etapa 6 estão armazenadas em `evidencias/`.

### Relação completa das evidências

1. `E6-01-validacao-inicial-e-escolha-rota-A.png`
2. `E6-01-validacao-inicial-e-escolha-rota2-A.png`
3. `E6-02-backup-e-rede-kind.png`
4. `E6-03-service-nodeport.png`
5. `E6-04-nginx-conectado-ao-kind.png`
6. `E6-05-verificacao-portas-openssl.png`
7. `E6-06-estrutura-nginx-edge.png`
8. `E6-07-certificado-autoassinado.png`
9. `E6-08-configuracao-nginx-https.png`
10. `E6-08-configuracao-nginx-https2.png`
11. `E6-09-validacao-configuracao-nginx.png`
12. `E6-10-nginx-edge-iniciado.png`
13. `E6-11b-resolucao-dns-local.png`
14. `E6-12-testes-http-https.png`
15. `E6-12-testes-http-https2.png`
16. `E6-13a-aviso-certificado-autoassinado.png`
17. `E6-14-teste-rate-limit.png`
18. `E6-15-investigacao-logs-nginx.png`
19. `E6-15-investigacao-logs-nginx2.png`
20. `E6-16-verificacao-logs-pods.png`
21. `E6-17-isolamento-acesso-direto.png`
22. `E6-18-validacao-final-servicos.png`
23. `E6-19-arquitetura-laboratorio.png`
24. `E6-19-arquitetura-laboratorio2.png`
25. `E6-20-destino-logs-nginx.png`
26. `E6-22-validacao-upstream-nginx.png`
27. `E6-23-reload-nginx.png`
28. `E6-24-estabilidade-https.png`
29. `E6-25-logs-requisicoes-nginx.png`
30. `E6-27-configuracao-logs-aplicacao.png`
31. `E6-28-verificacao-ambiente-node.png`
32. `E6-29-investigacao-logs-http.png`
33. `E6-30-localizacao-arquivos-logs.png`
34. `E6-31-consulta-logs-http-pod.png`
35. `E6-32-requisicao-com-marcador.png`
36. `E6-33-marcador-nos-logs-nginx.png`
37. `E6-34H-teste-conectividade-nodeport.png`
38. `E6-34I-log-requisicao-direta.png`
39. `E6-34J-processo-e-arquivo-log.png`
40. `E6-34L-configuracao-morgan-no-pod.png`
41. `E6-34N-comparacao-arquivo-log.png`
42. `E6-34O-verificacao-segundo-arquivo.png`
43. `E6-35-isolamento-porta-direta.png`
44. `E6-36-verificacao-exposicao-roteador.png`
45. `E6-37-cabecalhos-seguranca-https.png`
46. `E6-38-redirecionamento-http-https.png`
47. `E6-39-validacao-rate-limit.png`
48. `E6-40-correlacao-logs-nginx-pod.png`
49. `E6-40-diagnostico-inode-logs.png`
50. `E6-42-validacao-pos-limpeza.png`
51. `E6-42-verificacao-log-pod.png`
52. `E6-43-diagnostico-processo-logs.png`
53. `E6-44-contexto-middleware-morgan.png`

As capturas são registros do ambiente observado durante a execução. Elas não substituem a repetição dos testes em uma reprodução independente.

## 14. Estado registrado antes do teardown

Na validação registrada em 29/10/2026, às 14:38, o cluster `juiceshop-local` estava ativo, o Deployment possuía duas réplicas disponíveis e o Nginx Edge respondia localmente em HTTP e HTTPS.

Também estavam registrados o redirecionamento HTTP para HTTPS, os cabeçalhos de segurança e a limitação de requisições.

O teardown posterior foi documentado separadamente em:

`evidencias/E7-teardown-final.txt`

Esse registro informa que o cluster e os contêineres do projeto não estavam mais ativos, que as portas verificadas não estavam em escuta e que a entrada local do hostname havia sido removida.

Portanto, o estado descrito nesta seção é histórico e representa o ambiente antes da desmontagem, não o estado atual do laboratório.

## 15. Referência Git

Commit de referência da implementação:

`99ec228 — Configura Nginx Edge HTTPS para Juice Shop no kind`

Esse commit adicionou a documentação arquitetural, a configuração do Nginx Edge, o certificado público autoassinado e ajustes no Service Kubernetes.

A chave privada do certificado não deve ser versionada. O arquivo correspondente permanece protegido pelas regras do `.gitignore`.