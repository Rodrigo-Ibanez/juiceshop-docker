# Etapa 3 — Nginx como proxy reverso

## 1. Objetivo

Adicionar o Nginx à arquitetura Docker para atuar como proxy reverso do OWASP Juice Shop, mantendo a aplicação sem publicação direta de sua porta e permitindo acesso local por meio do proxy.

## 2. Arquitetura implementada

A partir desta etapa, a comunicação passou a ocorrer da seguinte forma:

1. O navegador acessa `http://localhost:8080`.
2. A requisição chega ao contêiner `juice-shop-nginx`.
3. O Nginx encaminha a requisição para `http://juice-shop:3000`.
4. O Juice Shop responde pela rede interna do Docker.
5. O Nginx devolve a resposta ao navegador.

Os contêineres utilizam a rede Docker `juice-internal`, do tipo bridge.

## 3. Configuração do Nginx

Configuração recuperada do commit `2721b81`:

- Imagem: `nginx:1.28-alpine`.
- Contêiner: `juice-shop-nginx`.
- Porta publicada: `127.0.0.1:8080:8080`.
- Arquivo de configuração: `nginx.conf`.
- Montagem da configuração: `/etc/nginx/nginx.conf`, somente leitura.
- Destino do proxy: `http://juice-shop:3000`.

### 3.1 Controles e cabeçalhos

A configuração implementou:

- `server_tokens off`: oculta a versão do Nginx nas respostas.
- `access_log`: registra requisições recebidas.
- `error_log`: registra erros com nível `warn`.
- `Host`: preserva o host original.
- `X-Real-IP`: encaminha o endereço IP do cliente.
- `X-Forwarded-For`: preserva a cadeia de IPs encaminhados.
- `X-Forwarded-Proto`: informa o protocolo utilizado na requisição original.
- HTTP/1.1 entre proxy e aplicação.
- Cabeçalho `Connection` vazio para o encaminhamento.

## 4. Integração com Docker Compose

O serviço Nginx foi adicionado ao arquivo `docker-compose.yml`.

Características registradas:

- Os serviços Juice Shop e Nginx compartilham a rede `juice-internal`.
- O Juice Shop não possui publicação direta de porta no host nesta configuração.
- O Nginx publica somente `127.0.0.1:8080`.
- O Nginx depende da condição `service_healthy` do Juice Shop.
- Ambos os serviços utilizam a política `restart: always`.

## 5. Evidências

As sete capturas identificadas para esta etapa estão em `evidencias/`:

1. `E3-01-estado-inicial-docker.png`
2. `E3-02-configuracao-nginx-validada.png`
3. `E3-03-acesso-via-nginx-porta-direta-bloqueada.png`
4. `E3-04-server-tokens-headers-logs.png`
5. `E3-04-server-tokens-headers2-logs.png`
6. `E3-05-arquivos-finais-validacao.png`
7. `E3-05-arquivos-finais-validacao2.png`

## 6. Segurança e isolamento

- O acesso ao Nginx foi vinculado ao endereço local `127.0.0.1`.
- A porta da aplicação não foi publicada diretamente no host nesta configuração.
- A comunicação entre Nginx e Juice Shop ocorre pela rede interna Docker.
- A configuração do Nginx é montada como somente leitura.
- O laboratório permanece sem exposição externa nesta etapa.

## 7. Decisões técnicas

O Nginx foi escolhido para centralizar a entrada HTTP da aplicação, evitando que o navegador acesse diretamente a porta interna do Juice Shop.

A rede Docker dedicada permite a comunicação entre os serviços sem necessidade de publicar a porta da aplicação no host.

A dependência baseada no healthcheck evita iniciar o proxy antes de a aplicação estar saudável.

## 8. Referência no histórico Git

- Commit: `2721b81`.
- Data: 27/10/2026.
- Mensagem: `feat: adiciona Nginx como proxy reverso do Juice Shop`.
