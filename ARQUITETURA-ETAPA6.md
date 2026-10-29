# Etapa 6 — Arquitetura, segurança e validação do OWASP Juice Shop

## 1. Objetivo

Documentar a arquitetura local do OWASP Juice Shop usando Nginx Edge como proxy reverso HTTPS, com a aplicação executando no Kubernetes kind.

O laboratório é destinado a treinamento. O Juice Shop é deliberadamente vulnerável e não deve receber dados reais, credenciais pessoais ou informações sensíveis.

## 2. Arquitetura

```text
+---------------------------------------+
| Navegador no Windows                  |
| https://juiceshop.local               |
+--------------------+------------------+
                     |
                     | Arquivo hosts
                     | juiceshop.local -> 127.0.0.1
                     v
+---------------------------------------+
| Nginx Edge — Docker                   |
| 127.0.0.1:80  -> redirecionamento 301 |
| 127.0.0.1:443 -> HTTPS                |
| Certificado autoassinado              |
| Cabeçalhos de segurança               |
| Rate limit                            |
+--------------------+------------------+
                     |
                     | Rede Docker: kind
                     | NodePort 30080
                     v
+---------------------------------------+
| Nó Kubernetes kind                    |
| IP Docker: 172.20.0.2                 |
| Namespace: juiceshop                  |
| Service: juice-shop                   |
| Tipo: NodePort                        |
+--------------------+------------------+
                     |
                     | Porta de serviço: 3000
                     v
+---------------------------------------+
| Deployment: juice-shop                |
| Réplicas disponíveis: 2/2             |
| Pod: 10.244.0.5                       |
| Pod: 10.244.0.2                       |
+---------------------------------------+
```

### Componentes confirmados

| Componente | Configuração |
|---|---|
| Cluster | `juiceshop-local` |
| Kubernetes | v1.37.0 |
| Namespace | `juiceshop` |
| Deployment | `juice-shop`, 2/2 disponíveis |
| Service | `NodePort`, porta 3000, NodePort 30080 |
| Imagem da aplicação | `bkimminich/juice-shop:v20.3.0` |
| Nginx Edge | `nginx:1.28-alpine` |
| Hostname local | `juiceshop.local` |

## 3. Decisão arquitetural

Foi escolhida a **rota A: Nginx Edge independente, conectado à rede Docker `kind` e encaminhando as requisições ao NodePort do Kubernetes**.

Essa opção reutiliza o Nginx como ponto de entrada e permite validar HTTPS, redirecionamento, cabeçalhos e limitação de requisições sem adicionar um controlador Ingress ao laboratório.

A alternativa de instalar um Ingress Controller não foi adotada porque acrescentaria componentes sem necessidade para o escopo local desta etapa.

O Nginx encaminha as requisições para `http://172.20.0.2:30080`. O Service Kubernetes distribui as requisições entre as réplicas disponíveis.

## 4. HTTPS e redirecionamento

- O hostname `juiceshop.local` é resolvido localmente para `127.0.0.1`.
- O Nginx publica a porta 80 em `127.0.0.1:80`.
- Requisições HTTP são redirecionadas para HTTPS com status `301`.
- O HTTPS utiliza certificado autoassinado.
- O navegador apresenta um aviso de confiança porque o certificado não foi emitido por uma autoridade certificadora reconhecida.
- O HTTPS foi validado com resposta `HTTP 200`.

O certificado autoassinado atende ao laboratório local, mas não equivale a um certificado público confiável.

## 5. Cabeçalhos de segurança

O Nginx foi configurado para fornecer os seguintes cabeçalhos:

| Cabeçalho | Valor validado |
|---|---|
| `Strict-Transport-Security` | `max-age=300` |
| `X-Content-Type-Options` | `nosniff` |
|