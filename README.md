# OWASP Juice Shop — Docker, Kubernetes e Nginx

## Objetivo

Preparar um ambiente local para executar o OWASP Juice Shop com Docker, Docker Compose, Kubernetes e Nginx, mantendo o serviço restrito à própria máquina durante esta etapa.

## Etapa 1 — Ambiente Docker

### Ambiente utilizado

- Sistema operacional do host: Windows 11 Pro
- Docker Desktop: 4.84.0
- Docker Engine: 29.6.2
- Git: 2.55.0.windows.3
- Backend: WSL 2
- Arquitetura: Linux x86_64
- CPUs disponibilizadas ao Docker: 8
- Memória disponibilizada ao Docker: aproximadamente 7,545 GiB

### Imagens, contêineres e máquinas virtuais

Uma imagem é o modelo que contém os arquivos e as dependências de uma aplicação; um contêiner é uma instância executável dessa imagem.

Uma máquina virtual executa um sistema operacional convidado com seu próprio kernel. Contêineres Linux compartilham o kernel Linux fornecido pelo ambiente Docker.

Neste projeto, não foi criada uma VM manual. O Docker Desktop utiliza WSL 2 como backend para executar contêineres Linux no Windows.

### Testes realizados

- `docker version`: cliente e servidor conectados.
- `docker run hello-world`: execução confirmada.
- `docker info`: ambiente Docker verificado.
- `docker logs teste-ciclo`: consulta dos logs.
- `docker stop teste-ciclo` e `docker rm teste-ciclo`: ciclo de parada e remoção confirmado.

### Ocorrência e resolução

O Docker Desktop inicialmente não iniciou porque o recurso opcional Windows Subsystem for Linux estava desabilitado. O recurso WSL foi habilitado e o cliente passou a se comunicar com o servidor Docker.

## Etapa 2 — Juice Shop com Docker Compose

### Imagem e configuração

- Imagem: `bkimminich/juice-shop:v20.3.0`
- Contêiner: `juice-shop`
- Porta local: `127.0.0.1:3000`
- Política de reinicialização configurada: `always`
- Healthcheck: requisição HTTP local, com intervalo de 30 segundos, timeout de 5 segundos, 3 tentativas e período inicial de 60 segundos.

Foi escolhida uma tag de versão fixa para tornar a implantação mais reproduzível, em vez de usar `latest`.

A porta foi vinculada a `127.0.0.1` para restringir o acesso direto à própria máquina. Não foi configurado acesso externo.

### Imagem versus contêiner e EXPOSE versus publicação de portas

Uma imagem é o pacote/modelo usado para criar contêineres; um contêiner é uma instância executável dessa imagem.

`EXPOSE` documenta a porta que a aplicação utiliza, mas não publica essa porta no host por si só.

`-p` no Docker ou `ports` no Compose cria um mapeamento entre uma porta do host e uma porta do contêiner. Neste projeto, `127.0.0.1:3000:3000` restringe o acesso publicado à própria máquina.

### Testes e resultados comprovados

- `docker compose config`: configuração validada.
- `docker compose up -d`: contêiner iniciado.
- `docker ps`: contêiner em execução, com estado `healthy`.
- `docker inspect`: política `always` e estado do healthcheck conferidos.
- `Invoke-WebRequest http://localhost:3000 -UseBasicParsing`: resposta HTTP 200.
- `docker compose down`: contêiner e rede do Compose removidos.
- `docker compose up -d`, após a remoção: contêiner e rede recriados com sucesso.
- Após a recriação: estado `running`, healthcheck `healthy` e resposta HTTP 200.

### Teste de reinicialização automática — aprovado

O teste foi realizado no próprio contêiner `juice-shop`, sem removê-lo ou recriá-lo. O processo principal recebeu `SIGTERM` por meio de um comando Node executado no contêiner.

Após o teste, `docker inspect` confirmou `Status=running`, `RestartPolicy=always` e `RestartCount=1`. A aplicação respondeu HTTP 200 durante a validação e, após aguardar a inicialização, o healthcheck passou para `healthy`.

Resultado: reinicialização automática comprovada no Juice Shop.

Evidência: `E2-08-reinicializacao-automatica-comprovada.png`.

### Avisos opcionais da aplicação

Os logs registraram avisos sobre a ausência de `ALCHEMY_API_KEY` e sobre um endpoint local de Ollama indisponível. Esses avisos afetam desafios opcionais de Web3 e IA, mas não impediram o início da aplicação nem a resposta HTTP 200.

### Decisão técnica

Escolhi `bkimminich/juice-shop:v20.3.0` porque a tag fixa favorece a reprodução da implantação. A porta foi vinculada a `127.0.0.1` para manter o acesso local e reduzir a exposição desnecessária.

### Evidências

Registrar e anexar as capturas reais produzidas durante a etapa, incluindo:

- `E2-01-docker-version.png`
- `E2-02-docker-info.png`
- `E2-03-compose-validado.png`
- `E2-04-juice-shop-local-e-docker-ps.png`
- `E2-05-acesso-local-restaurado.png`
- `E2-06-compose-down.png`
- `E2-07-compose-up-recriacao.png`
- `E2-08-reinicializacao-automatica-comprovada.png`

A evidência do teste de reinicialização automática está registrada em E2-08-reinicializacao-automatica-comprovada.png.

## Segurança

O OWASP Juice Shop é intencionalmente vulnerável e destinado a treinamento. Utilizar somente dados fictícios, manter o ambiente local e não expor portas à internet. Não registrar senhas, tokens ou outros segredos no repositório.

## Etapa 3 — Nginx como proxy reverso

### Objetivo

Adicionar o Nginx como ponto de entrada HTTP do Juice Shop, mantendo os dois serviços em uma rede Docker compartilhada e sem publicar diretamente a porta 3000 no Windows.

### Arquitetura implementada

- Aplicação: `bkimminich/juice-shop:v20.3.0`
- Contêiner da aplicação: `juice-shop`
- Proxy reverso: `nginx:1.28-alpine`
- Contêiner do proxy: `juice-shop-nginx`
- Rede Docker: `juice-internal`
- Porta publicada no host: `127.0.0.1:8080`
- Porta interna do Juice Shop: `3000`
- Arquivo de configuração: `nginx.conf`
- Montagem do arquivo: somente leitura (`ro`)
- Política de reinicialização dos serviços: `always`

O navegador acessa `http://localhost:8080`. O Nginx encaminha a requisição para `http://juice-shop:3000`, usando a resolução de nomes da rede Docker Compose.

A porta 3000 não é publicada no host. Os testes realizados confirmaram HTTP 200 pela porta 8080 e indisponibilidade do acesso direto por `localhost:3000`.

### Configuração do Nginx

O arquivo `nginx.conf` utilizado:

```nginx
worker_processes auto;

events {
    worker_connections 1024;
}

http {
    # Oculta a versao do Nginx nas respostas.
    server_tokens off;

    # Registra as requisicoes recebidas pelo proxy.
    access_log /var/log/nginx/access.log;
    error_log  /var/log/nginx/error.log warn;

    server {
        listen 8080;
        server_name _;

        location / {
            # Nome do servico Compose na rede Docker interna.
            proxy_pass http://juice-shop:3000;

            # Preserva informacoes da requisicao original.
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            proxy_http_version 1.1;
            proxy_set_header Connection "";
        }
    }
}
```

O arquivo é montado em `/etc/nginx/nginx.conf` com a opção `ro`, impedindo que o contêiner altere diretamente o arquivo de configuração do host.

### Conceitos técnicos

#### Proxy reverso

O proxy reverso recebe as requisições dos clientes e as encaminha para a aplicação de destino. Neste projeto, o Nginx centraliza a entrada HTTP e evita a publicação direta da porta 3000 no host.

#### `proxy_pass`

Define o destino das requisições encaminhadas. O nome `juice-shop` corresponde ao serviço definido no Compose e é resolvido pela rede Docker compartilhada.

#### Cabeçalhos encaminhados

- `Host`: encaminha o nome do host solicitado.
- `X-Real-IP`: registra o endereço remoto observado pelo Nginx.
- `X-Forwarded-For`: mantém a cadeia de endereços IP encaminhados.
- `X-Forwarded-Proto`: informa o protocolo usado entre cliente e proxy.
- `Connection`: é enviado vazio para evitar o encaminhamento direto desse cabeçalho de conexão.

Neste ambiente local, o acesso ao proxy utiliza HTTP. Portanto, `X-Forwarded-Proto` informa `http`; isso não significa que exista criptografia TLS.

#### `server_tokens off`

Oculta a versão do Nginx no cabeçalho de resposta `Server`. O teste apresentou `Server: nginx`, sem o número da versão.

Essa configuração reduz a divulgação de detalhes sobre o software, mas não substitui atualizações, controle de acesso ou outras medidas de segurança.

#### `nginx -t`

Valida a sintaxe e a consistência da configuração do Nginx. A validação foi executada com:

```powershell
docker compose run --rm --no-deps nginx nginx -t
```

Resultado observado: `syntax is ok` e `test is successful`.

#### Logs

O Nginx registra requisições em `/var/log/nginx/access.log` e ocorrências relevantes em `/var/log/nginx/error.log`.

A consulta dos logs do contêiner confirmou requisições HTTP com status 200, incluindo a requisição de teste `/?e3-log-test=1`.

### Testes realizados e resultados

- `docker compose config --quiet`: configuração do Compose validada.
- `docker compose run --rm --no-deps nginx nginx -t`: configuração do Nginx validada.
- `docker compose ps`: Juice Shop em estado `healthy` e Nginx em execução.
- `Invoke-WebRequest http://localhost:8080 -UseBasicParsing`: HTTP 200.
- `Invoke-WebRequest http://localhost:3000 -UseBasicParsing -TimeoutSec 5`: acesso direto indisponível no host.
- `Invoke-WebRequest http://localhost:8080/?e3-log-test=1 -UseBasicParsing`: requisição de teste registrada no log de acesso.
- Cabeçalho HTTP: `Server: nginx`, sem a versão.
- `docker compose logs --tail 10 nginx`: registros de requisições HTTP com status 200.

### O que a solução resolve

- Centraliza a entrada HTTP no Nginx.
- Evita publicar diretamente a porta 3000 no host.
- Permite manter a configuração do proxy em um arquivo versionável no projeto.
- Encaminha informações da requisição por cabeçalhos apropriados.
- Registra as requisições recebidas pelo proxy.
- Oculta a versão do Nginx nas respostas HTTP.

### Limitações e cuidados de segurança

O proxy reverso não corrige as vulnerabilidades intencionais do OWASP Juice Shop, não substitui autenticação, não implementa por si só filtragem de requisições maliciosas e não fornece HTTPS nesta configuração.

A rede `juice-internal` é uma rede bridge compartilhada pelos serviços. Outros contêineres conectados à mesma rede também poderão alcançar o serviço interno. Portanto, a ausência de publicação da porta 3000 no host não significa isolamento absoluto entre contêineres.

O mapeamento `127.0.0.1:8080:8080` limita a publicação do Nginx à interface de loopback do host. Não foi configurado acesso externo, encaminhamento de portas no roteador ou exposição do serviço à internet.

O Juice Shop é intencionalmente vulnerável e deve continuar sendo utilizado somente para treinamento, com dados fictícios e sem credenciais reais.

### Evidências da Etapa 3

- `E3-01-estado-inicial-docker.png`
- `E3-02-configuracao-nginx-validada.png`
- `E3-03-acesso-via-nginx-porta-direta-bloqueada.png`
- `E3-04-server-tokens-headers-logs.png`
- `E3-05-arquivos-finais-validacao.png`

As capturas devem corresponder aos testes efetivamente realizados e ser armazenadas junto da documentação do projeto.

### Status

A arquitetura com Nginx, a validação da configuração, o acesso pelo proxy e a ausência de publicação direta da porta 3000 foram comprovados. A revisão final da documentação e o registro das alterações no Git fazem parte do fechamento desta etapa.
