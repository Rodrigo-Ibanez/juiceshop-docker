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
| `X-Frame-Options` | `SAMEORIGIN` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |

Esses cabeçalhos oferecem proteções específicas, mas não eliminam as vulnerabilidades intencionais do Juice Shop.

## 6. Limitação de requisições

A configuração utiliza uma zona de limitação por endereço remoto, com taxa de 5 requisições por segundo, tolerância de rajada de 10 requisições e resposta HTTP 429 quando o limite é excedido.

No teste realizado, uma sequência de 40 requisições produziu 24 respostas HTTP 200 e 16 respostas HTTP 429. Esse resultado corresponde ao teste observado, não a uma proporção garantida em todas as execuções.

## 7. Logs e correlação

O Nginx registra acessos em `/var/log/nginx/access.log` e ocorrências relevantes em `/var/log/nginx/error.log`.

A requisição com o marcador `E47-CORRELACAO-FINAL` apareceu no log do Nginx e no log da aplicação de um dos pods. A ausência do marcador no outro pod é compatível com o balanceamento de requisições entre réplicas.

Os logs da aplicação também podem ser gravados em arquivos internos, como `/juice-shop/logs/access.log.DATE`, e não aparecer integralmente em `kubectl logs`.

## 8. Isolamento e exposição

O Nginx Edge publica somente `127.0.0.1:80` e `127.0.0.1:443`. O Service Kubernetes usa NodePort 30080, mas essa porta não está publicada diretamente no Windows.

O acesso direto pelo endereço de loopback do Windows foi testado e não estava disponível. Conforme a verificação registrada, não há encaminhamento de portas ou DMZ ativos no roteador para este laboratório, e as regras específicas de encaminhamento do Windows foram removidas.

Esses resultados descrevem o estado observado; devem ser verificados novamente antes de qualquer demonstração futura.

## 9. Responsabilidades das tecnologias

| Tecnologia | Responsabilidade |
|---|---|
| Docker | Executa contêineres e fornece a rede utilizada pelo Nginx Edge e pelo nó do kind. |
| kind | Executa um cluster Kubernetes local usando contêineres Docker como nós. |
| Kubernetes | Gerencia pods, réplicas, verificações de saúde e Service do Juice Shop. |
| Nginx | Centraliza a entrada HTTP/HTTPS, redireciona HTTP, termina TLS, aplica cabeçalhos e limita requisições. |

## 10. Dificuldades e decisões

- **Acesso ao NodePort:** o NodePort não estava disponível diretamente em `127.0.0.1` no Windows. O Nginx foi conectado à rede Docker `kind` para encaminhar as requisições ao nó.
- **Certificado autoassinado:** o HTTPS funcionou, mas o navegador apresentou um aviso de confiança, esperado para um certificado não confiado pelo sistema.
- **Logs da aplicação:** foi necessário localizar os arquivos internos e correlacionar os registros com o Nginx.
- **Endereço do nó:** o upstream utiliza um IP fixado na configuração. Se o cluster for recriado, é necessário consultar o IP atual, atualizar `nginx-edge/nginx.conf`, validar com `docker exec juice-shop-nginx-edge nginx -t` e recarregar com `docker exec juice-shop-nginx-edge nginx -s reload`.

## 11. O que faria diferente

Para tornar a reprodução mais robusta, automatizaria a descoberta do endereço do nó e a geração da configuração do Nginx.

Um Ingress Controller poderia ser avaliado se o escopo passasse a exigir múltiplas aplicações ou roteamento mais declarativo. Ele não foi necessário para os objetivos deste laboratório.

## 12. Limitações e cuidados

O proxy reverso, o HTTPS e os cabeçalhos não corrigem as vulnerabilidades intencionais da aplicação. O certificado é autoassinado e o endereço do nó pode mudar.

O laboratório deve permanecer local, com dados fictícios e sem credenciais reais. Não habilitar encaminhamento de portas, DMZ ou exposição pública sem autorização e avaliação de risco.

## 13. Evidências

As capturas das Etapas 2 a 6 estão em `docs/evidencias/`. Entre as evidências relevantes estão:

- `E6-06-estrutura-nginx-edge.png`
- `E6-07-certificado-autoassinado.png`
- `E6-09-validacao-configuracao-nginx.png`
- `E6-12-testes-http-https.png`
- `E6-14-teste-rate-limit.png`
- `E6-19-arquitetura-laboratorio.png`
- `E6-35-isolamento-porta-direta.png`
- `E6-37-cabecalhos-seguranca-https.png`
- `E6-38-redirecionamento-http-https.png`
- `E6-39-validacao-rate-limit.png`
- `E6-40-correlacao-logs-nginx-pod.png`
- `E6-42-validacao-pos-limpeza.png`

As capturas são registros do ambiente observado e não substituem a repetição dos testes em uma reprodução independente.

## 14. Estado registrado

Na validação registrada, o cluster `juiceshop-local` estava ativo, o Deployment tinha duas réplicas disponíveis e o Nginx Edge respondia localmente em HTTP/HTTPS, com redirecionamento, cabeçalhos e limitação de requisições.

A documentação deve ser revisada antes da entrega final. Desmontar o laboratório somente depois de gravar a demonstração e confirmar que o ambiente não é mais necessário.
