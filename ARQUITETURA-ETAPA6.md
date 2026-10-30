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
                     | Upstream DNS:
                     | juiceshop-local-control-plane
                     | NodePort 30080
                     v
+---------------------------------------+
| Nó Kubernetes kind                    |
| Nome: juiceshop-local-control-plane   |
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

### Componentes registrados

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
| Nó do kind usado no upstream | `juiceshop-local-control-plane` |

Os endereços dos pods são os registrados na captura da validação. Eles podem mudar quando o cluster for recriado.

## 3. Decisão arquitetural

Foi escolhida a **rota A: Nginx Edge independente, conectado à rede Docker `kind` e encaminhando as requisições ao NodePort do Kubernetes**.

Essa opção reutiliza o Nginx como ponto de entrada e permite validar HTTPS, redirecionamento, cabeçalhos e limitação de requisições sem adicionar um controlador Ingress ao laboratório.

A alternativa de instalar um Ingress Controller não foi adotada porque acrescentaria componentes sem necessidade para o escopo local desta etapa.

O Nginx encaminha as requisições para:

`http://juiceshop-local-control-plane:30080`

O nome do nó é resolvido pela rede Docker compartilhada com o kind. O Service Kubernetes recebe as requisições e distribui o tráfego entre as réplicas disponíveis.

Essa configuração evita depender de um endereço IP fixo do nó.

## 4. HTTPS e redirecionamento

- O hostname `juiceshop.local` é resolvido localmente para `127.0.0.1`.
- O Nginx publica a porta 80 em `127.0.0.1:80`.
- O Nginx publica a porta 443 em `127.0.0.1:443`.
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

O acesso direto pelo endereço de loopback do Windows foi testado e não estava disponível.

Conforme os registros da etapa, as regras específicas de encaminhamento do Windows foram removidas e não havia encaminhamento de portas ou DMZ ativos no roteador para este laboratório. A verificação independente do roteador deve ser considerada separadamente, pois a documentação não substitui essa conferência.

Esses resultados descrevem o estado observado durante a validação. Antes de qualquer demonstração futura, as configurações de rede, firewall e roteador devem ser verificadas novamente.

## 9. Responsabilidades das tecnologias

| Tecnologia | Responsabilidade |
|---|---|
| Docker | Executa contêineres e fornece a rede utilizada pelo Nginx Edge e pelo nó do kind. |
| kind | Executa um cluster Kubernetes local usando contêineres Docker como nós. |
| Kubernetes | Gerencia pods, réplicas, verificações de saúde e Service do Juice Shop. |
| Nginx | Centraliza a entrada HTTP/HTTPS, redireciona HTTP, termina TLS, aplica cabeçalhos e limita requisições. |

## 10. Dificuldades e decisões

- **Acesso ao NodePort:** o NodePort não estava disponível diretamente em `127.0.0.1` no Windows. O Nginx foi conectado à rede Docker `kind` para encaminhar as requisições ao nó.
- **Descoberta do endereço do nó:** inicialmente foi considerada a utilização do IP do contêiner. A configuração definitiva utiliza o nome DNS `juiceshop-local-control-plane`, evitando a dependência de um IP fixo.
- **Certificado autoassinado:** o HTTPS funcionou, mas o navegador apresentou um aviso de confiança, esperado para um certificado não confiado pelo sistema.
- **Logs da aplicação:** foi necessário localizar os arquivos internos e correlacionar os registros com o Nginx.

### Reprodução após recriar o cluster

O Nginx utiliza o nome DNS do nó do kind como upstream:

`http://juiceshop-local-control-plane:30080`

A configuração não exige atualização manual de IP quando o endereço interno do nó muda. Para reproduzir o ambiente, o cluster deve ser criado com o nome esperado, e o contêiner Nginx deve estar conectado à rede Docker `kind`.

Depois da inicialização, a configuração pode ser validada com:

```bash
docker exec juice-shop-nginx-edge nginx -t
```

Essa validação confirma a sintaxe do Nginx. A comunicação com o upstream também deve ser testada por meio de uma requisição HTTPS à aplicação.

## 11. O que faria diferente

Para tornar a reprodução mais robusta, automatizaria a criação do cluster, a conexão do Nginx à rede Docker e as verificações de disponibilidade do upstream.

Um Ingress Controller poderia ser avaliado se o escopo passasse a exigir múltiplas aplicações ou roteamento mais declarativo. Ele não foi necessário para os objetivos deste laboratório.

## 12. Limitações e cuidados

O proxy reverso, o HTTPS e os cabeçalhos não corrigem as vulnerabilidades intencionais da aplicação. O certificado é autoassinado e o laboratório depende da existência da rede Docker e do nome esperado do nó do kind.

O laboratório deve permanecer local, com dados fictícios e sem credenciais reais. Não habilitar encaminhamento de portas, DMZ ou exposição pública sem autorização e avaliação de risco.

## 13. Evidências

As capturas das Etapas 2 a 6 estão em `evidencias/`. Entre as evidências relevantes estão:

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

## 14. Estado registrado antes do teardown

Na validação registrada em 29/10/2026, às 14:38, o cluster `juiceshop-local` estava ativo, o Deployment tinha duas réplicas disponíveis e o Nginx Edge respondia localmente em HTTP/HTTPS, com redirecionamento, cabeçalhos e limitação de requisições.

O teardown posterior foi registrado separadamente em `evidencias/E7-teardown-final.txt`. Esse registro informa que o cluster e os contêineres do projeto não estavam mais ativos, que as portas verificadas não estavam em escuta e que a entrada local do hostname havia sido removida.

Portanto, o estado descrito nesta seção é histórico e representa o ambiente antes da desmontagem, não o estado atual do laboratório.
