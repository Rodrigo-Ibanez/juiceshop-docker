# Etapa 1 — Preparação do ambiente Docker

## 1. Objetivo

Preparar e validar o ambiente Docker no Windows para executar posteriormente o OWASP Juice Shop com contêineres Linux, mantendo o laboratório local e sem exposição à internet.

## 2. Ambiente utilizado

Informações registradas no README versionado no primeiro marco da etapa:

- Sistema operacional do host: Windows 11 Pro.
- Docker Desktop: 4.84.0.
- Docker Engine: 29.6.2.
- Git: 2.55.0.windows.3.
- Backend do Docker Desktop: WSL 2.
- Arquitetura dos contêineres: Linux x86_64.

## 3. Conceitos e decisões técnicas

Uma imagem Docker é um modelo que contém os arquivos e as dependências necessários para executar uma aplicação. Um contêiner é uma instância executável dessa imagem, isolada dos demais processos por recursos do sistema operacional.

Uma máquina virtual executa um sistema operacional convidado sobre hardware virtualizado. Contêineres Linux compartilham o kernel Linux fornecido pelo ambiente Docker, enquanto uma VM possui seu próprio kernel convidado.

Neste projeto, não foi criada uma VM manual. O Docker Desktop utiliza o WSL 2 como backend para executar contêineres Linux no Windows. Isso atende à exigência de trabalhar sem criar uma VM manual no Hyper-V, VirtualBox ou VMware.

Decisões registradas:

- Utilizar Docker Desktop com backend WSL 2.
- Não criar VM manual, conforme o requisito da atividade.
- Não publicar portas nem configurar acesso externo.
- Utilizar Git para versionar configurações, documentação e alterações por etapa.

## 4. Testes registrados

Os seguintes testes foram documentados no README presente no commit `9d1207d`:

| Comando | Resultado registrado |
|---|---|
| `docker version` | Cliente e servidor conectados. |
| `docker run hello-world` | Imagem baixada e contêiner executado com sucesso. |
| `docker info` | Ambiente confirmado com 8 CPUs e aproximadamente 7,545 GiB de memória disponíveis para o Docker. |
| `docker ps` | Contêiner de teste identificado em execução. |
| `docker logs teste-ciclo` | Mensagens do processo consultadas. |
| `docker stop teste-ciclo` | Contêiner parado. |
| `docker rm teste-ciclo` | Contêiner removido. |
| `docker ps -a` | Remoção confirmada. |

A documentação histórica também registra um teste com o contêiner Alpine, concluído com sucesso. O comando específico desse teste não foi preservado no README consultado.

Os resultados acima foram recuperados da documentação versionada no commit `9d1207d`. Este documento não representa uma nova execução desses testes.

## 5. Ocorrência e resolução

A documentação original registra que o Docker Desktop inicialmente não iniciou porque o recurso opcional Windows Subsystem for Linux estava desabilitado.

A Plataforma de Máquina Virtual já estava habilitada. O recurso WSL foi habilitado e, após a correção, o comando `docker version` passou a apresentar cliente e servidor.

Os testes com `hello-world` e com o contêiner Alpine foram registrados como concluídos com sucesso.

## 6. Segurança

O OWASP Juice Shop é uma aplicação intencionalmente vulnerável, destinada a treinamento.

Cuidados definidos para o laboratório:

- Utilizar somente dados fictícios.
- Manter o ambiente local.
- Não expor portas à internet.
- Não registrar senhas, tokens ou outros segredos no repositório.

## 7. Evidências

O inventário atual de `evidencias/` não identificou uma captura visual específica da Etapa 1.

A documentação desta etapa foi recuperada do README presente no commit `9d1207d`, de 20/10/2026.

Não se afirma a existência de uma captura que não foi localizada.

## 8. Referência no histórico Git

- Commit: `9d1207d`
- Data: 20/10/2026
- Mensagem: `docs: documenta ambiente Docker da etapa 1`
