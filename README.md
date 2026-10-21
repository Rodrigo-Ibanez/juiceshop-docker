# OWASP Juice Shop — Docker, Kubernetes e Nginx

## Objetivo

Preparar um ambiente local para executar o OWASP Juice Shop usando Docker, Kubernetes e Nginx, sem publicar o serviço na internet.

## Etapa 1 — Ambiente Docker

### Ambiente utilizado

- Sistema operacional do host: Windows 11 Pro
- Docker Desktop: 4.84.0
- Docker Engine: 29.6.2
- Git: 2.55.0.windows.3
- Backend do Docker Desktop: WSL 2
- Arquitetura dos contêineres: Linux x86_64

### Contêiner, imagem e máquina virtual

Uma imagem Docker é um modelo que contém os arquivos e as dependências necessários para executar uma aplicação. Um contêiner é uma instância executável dessa imagem, isolada dos demais processos por recursos do sistema operacional.

Uma máquina virtual executa um sistema operacional convidado sobre hardware virtualizado. Contêineres Linux compartilham o kernel Linux fornecido pelo ambiente Docker, enquanto uma VM possui seu próprio kernel convidado.

Neste projeto, não criamos uma VM manual. O Docker Desktop usa o WSL 2 como backend para executar contêineres Linux no Windows. Isso atende à exigência de trabalhar sem criar uma VM no Hyper-V, VirtualBox ou VMware.

### Testes realizados

- `docker version`: cliente e servidor conectados.
- `docker run hello-world`: imagem baixada e contêiner executado com sucesso.
- `docker info`: ambiente confirmado com 8 CPUs e aproximadamente 7,545 GiB de memória disponíveis para o Docker.
- `docker ps`: contêiner de teste identificado em execução.
- `docker logs teste-ciclo`: mensagens do processo consultadas.
- `docker stop teste-ciclo`: contêiner parado.
- `docker rm teste-ciclo`: contêiner removido.
- `docker ps -a`: remoção confirmada.

### Decisões técnicas

- Docker Desktop com backend WSL 2: escolhido para executar contêineres Linux no Windows.
- Não criar VM manual: requisito da Fase 2.
- Não publicar portas nem configurar acesso externo: todo o ambiente deve permanecer local.
- Git: escolhido para versionar configurações, documentação e alterações por etapa.

### Ocorrência e resolução

O Docker Desktop inicialmente não iniciou porque o recurso opcional Windows Subsystem for Linux estava desabilitado. A Plataforma de Máquina Virtual já estava habilitada. O recurso WSL foi habilitado e, após a correção, `docker version` passou a mostrar cliente e servidor. Os testes `hello-world` e do contêiner Alpine foram concluídos com sucesso.

### Segurança

O OWASP Juice Shop é uma aplicação intencionalmente vulnerável para treinamento. O ambiente deve usar somente dados fictícios, permanecer local e não expor portas à internet. Não registrar senhas, tokens ou outros segredos neste repositório.
