# Etapa 2 — Execução do Juice Shop com Docker Compose

## 1. Objetivo

Executar o OWASP Juice Shop em um contêiner Docker, utilizando Docker Compose, mantendo o serviço acessível somente pela própria máquina.

## 2. Configuração utilizada

Configuração recuperada do commit `c1f1ef9`:

| Item | Configuração |
|---|---|
| Imagem | `bkimminich/juice-shop:v20.3.0` |
| Contêiner | `juice-shop` |
| Porta publicada | `127.0.0.1:3000:3000` |
| Política de reinicialização | `always` |
| Healthcheck | Requisição HTTP local |
| Intervalo | 30 segundos |
| Timeout | 5 segundos |
| Tentativas | 3 |
| Período inicial | 60 segundos |

O mapeamento da porta para `127.0.0.1` restringiu o acesso publicado à interface local da máquina.

## 3. Testes e resultados

Os testes abaixo foram registrados na documentação versionada da etapa:

| Comando | Resultado registrado |
|---|---|
| `docker compose config` | Configuração validada. |
| `docker compose up -d` | Contêiner iniciado. |
| `docker ps` | Contêiner em execução e `healthy`. |
| `docker inspect` | Política `always` e estado do healthcheck conferidos. |
| `Invoke-WebRequest http://localhost:3000 -UseBasicParsing` | Resposta HTTP 200. |
| `docker compose down` | Contêiner e rede removidos. |
| `docker compose up -d` | Contêiner e rede recriados. |
| Nova consulta de estado e HTTP | Estado `running`, healthcheck `healthy` e HTTP 200. |

Esses resultados foram recuperados do histórico Git. Este documento não representa uma nova execução dos testes.

## 4. Teste de reinicialização automática

O teste de reinicialização automática foi inicialmente registrado como pendente.

Os primeiros testes com `docker kill` e um contêiner auxiliar Alpine não comprovaram a recuperação automática. Por isso, o requisito não foi considerado aprovado naquele momento.

Em uma validação posterior, registrada no commit `f635180`, o teste foi realizado no próprio contêiner `juice-shop`, sem removê-lo ou recriá-lo.

O processo principal recebeu `SIGTERM` por meio de um comando Node executado no contêiner.

Após o teste, foram registrados os seguintes resultados:

- `Status=running`.
- `RestartPolicy=always`.
- `RestartCount=1`.
- Aplicação respondendo HTTP 200.
- Healthcheck retornando para `healthy` após a inicialização.

**Resultado registrado: reinicialização automática comprovada.**

Evidência: `E2-08-reinicializacao-automatica-comprovada.png`.

## 5. Evidências

As nove capturas identificadas para esta etapa estão em `evidencias/`:

1. `E2-01-docker-version.png`
2. `E2-02-docker-info.png`
3. `E2-02-docker-info2.png`
4. `E2-03-compose-validado.png`
5. `E2-04-juice-shop-local-e-docker-ps.png`
6. `E2-05-acesso-local-restaurado.png`
7. `E2-06-compose-down.png`
8. `E2-07-compose-up-recriacao.png`
9. `E2-08-reinicializacao-automatica-comprovada.png`

## 6. Segurança

- O serviço foi publicado somente em `127.0.0.1`.
- Não foi configurada exposição externa nesta etapa.
- O Juice Shop é intencionalmente vulnerável e deve ser utilizado somente em ambiente de laboratório.
- Devem ser utilizados dados fictícios.
- Senhas, tokens e outros segredos não devem ser registrados no repositório.

## 7. Dificuldades e decisões

A validação da reinicialização automática exigiu mais de uma tentativa.

Os primeiros testes não demonstraram a recuperação esperada. Em vez de considerar a política `always` suficiente por si só, o teste foi repetido no contêiner real da aplicação.

A aprovação só foi registrada depois da confirmação do incremento de `RestartCount`, do estado `running` e da recuperação do healthcheck.

## 8. Referências no histórico Git

- Commit `c1f1ef9` — 22/10/2026: `feat: executar Juice Shop com Docker Compose`.
- Commit `f635180` — 22/10/2026: `docs: registra reinicializacao automatica do Juice Shop`.
