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

### Teste de reinicialização automática — pendente

A política `always` está configurada no Compose e foi confirmada por `docker inspect`. Entretanto, os testes realizados até agora não comprovaram a recuperação automática após o encerramento do processo principal.

Os testes com `docker kill` terminaram com o contêiner em estado `exited` e `RestartCount=0`. O teste auxiliar com Alpine também não comprovou uma reinicialização. Portanto, este requisito permanece pendente de validação; não é considerado aprovado.

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

A evidência do teste de reinicialização automática só deve ser adicionada depois de um teste válido e bem-sucedido.

## Segurança

O OWASP Juice Shop é intencionalmente vulnerável e destinado a treinamento. Utilizar somente dados fictícios, manter o ambiente local e não expor portas à internet. Não registrar senhas, tokens ou outros segredos no repositório.
