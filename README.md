# OWASP Juice Shop — Docker, Kubernetes e Nginx

## Objetivo

Documentar a implantação local do OWASP Juice Shop usando Docker, Docker Compose, Kubernetes com kind e Nginx como proxy reverso HTTPS.

> O OWASP Juice Shop é intencionalmente vulnerável e destinado a treinamento. Use somente dados fictícios e não exponha o laboratório publicamente sem autorização.

## Estado do projeto

As Etapas 1 a 6 foram desenvolvidas e documentadas. A arquitetura final utiliza um cluster Kubernetes local criado com kind, duas réplicas do Juice Shop e um Nginx Edge que publica HTTP e HTTPS somente em 127.0.0.1.

A documentação técnica detalhada está em [ARQUITETURA-ETAPA6.md](ARQUITETURA-ETAPA6.md).

## Ambiente validado

| Componente | Versão ou configuração observada |
|---|---|
| Sistema operacional | Windows 11 Pro, build 26200 |
| Docker Engine | 29.6.2 |
| Git | 2.55.0.windows.3 |
| kind | v0.33.0 |
| kubectl | v1.36.1 |
| Kubernetes do nó kind | v1.37.0 |
| Sistema operacional do nó | Debian GNU/Linux 13 |
| Réplicas disponíveis | 2/2 |
| Imagem do Juice Shop | `bkimminich/juice-shop:v20.3.0` |
| Nginx Edge | `nginx:1.28-alpine` |

As versões representam o ambiente observado em 29/10/2026 e podem mudar em instalações futuras.

## Arquitetura final

```text
Navegador no Windows
        |
        | 127.0.0.1:80 / 443
        v
Nginx Edge (Docker)
        |
        | NodePort 30080 na rede Docker kind
        v
Nó do cluster kind
        |
        v
Service Kubernetes: juice-shop
        |
        v
Deployment: 2 réplicas
        |
        v
Pods do OWASP Juice Shop: 3000
```

O nome local utilizado é `juiceshop.local`, associado a `127.0.0.1` no arquivo hosts do Windows. O certificado TLS é autoassinado e não será confiável automaticamente em todos os clientes.

## Responsabilidades das tecnologias

- **Docker:** executa contêineres.
- **Docker Compose:** descreve a implantação inicial das Etapas 2 e 3.
- **kind:** cria um cluster Kubernetes local dentro de contêineres.
- **Kubernetes:** gerencia Deployment, Pods, réplicas e Service.
- **Nginx Edge:** centraliza o acesso HTTP/HTTPS local, aplica redirecionamento, cabeçalhos, limite de requisições e logs.

Os arquivos Compose documentam a arquitetura inicial. A arquitetura final é Kubernetes com Nginx Edge.

## Estrutura do projeto

```text
.
|-- README.md
|-- ARQUITETURA-ETAPA6.md
|-- docker-compose.yml
|-- nginx.conf
|-- kind-config.yaml
|-- k8s/
|   |-- namespace.yaml
|   |-- deployment.yaml
|   `-- service.yaml
|-- nginx-edge/
|   |-- nginx.conf
|   `-- certs/
|       |-- juiceshop.local.crt
|       `-- juiceshop.local.key (privado; não versionar)
`-- docs/evidencias/
```

A pasta `backup-etapa6/` contém arquivos de referência. Inspecione seu conteúdo antes de decidir se deve ser incluída na entrega.


## Implantação a partir de um clone limpo

Pré-requisitos: Docker Desktop em execução, PowerShell, Git, `kind`, `kubectl` e acesso à internet. Execute os comandos na raiz do repositório.

O nome padrão do cluster é `juiceshop-local`. Para testar em paralelo com outro ambiente, use um nome exclusivo e ajuste o upstream do Nginx conforme indicado abaixo.

### 1. Criar o cluster

Para a implantação padrão:

```powershell
kind create cluster --config .\kind-config.yaml
kubectl wait --for=condition=Ready nodes --all --timeout=180s
```

Para uma prova isolada, copie o arquivo de configuração e altere o nome do cluster antes de criá-lo:

```powershell
Copy-Item .\kind-config.yaml .\kind-config-prova.yaml
(Get-Content .\kind-config-prova.yaml) -replace 'name: juiceshop-local', 'name: juiceshop-prova' | Set-Content .\kind-config-prova.yaml
kind create cluster --config .\kind-config-prova.yaml
kubectl wait --for=condition=Ready nodes --all --timeout=180s
```

### 2. Implantar o Juice Shop

```powershell
kubectl apply -f .\k8s\namespace.yaml
kubectl apply -f .\k8s\deployment.yaml
kubectl apply -f .\k8s\service.yaml
kubectl -n juiceshop rollout status deployment/juice-shop --timeout=300s
kubectl -n juiceshop get deployment,service,pods -o wide
```

Confirme que as duas réplicas estão prontas.

### 3. Gerar o certificado TLS local

A chave privada é local e não deve ser versionada.

```powershell
docker run --rm -v "${PWD}\nginx-edge\certs:/certs" alpine/openssl req -x509 -nodes -days 30 -newkey rsa:2048 -keyout /certs/juiceshop.local.key -out /certs/juiceshop.local.crt -subj "/CN=juiceshop.local" -addext "subjectAltName=DNS:juiceshop.local,IP:127.0.0.1"
```

### 4. Iniciar o Nginx Edge

Para o cluster padrão, o upstream é:

```nginx
proxy_pass http://juiceshop-local-control-plane:30080;
```

Para a prova isolada com `juiceshop-prova`, altere somente a cópia local de `nginx-edge/nginx.conf` para:

```nginx
proxy_pass http://juiceshop-prova-control-plane:30080;
```

Crie o Nginx Edge na rede `kind`, publicando as portas apenas no loopback do Windows:

```powershell
docker run -d --name juice-shop-nginx-edge-prova --network kind -p 127.0.0.1:8080:80 -p 127.0.0.1:8443:443 -v "${PWD}\nginx-edge\nginx.conf:/etc/nginx/nginx.conf:ro" -v "${PWD}\nginx-edge\certs:/etc/nginx/certs:ro" nginx:1.28-alpine
```

### 5. Validar o ambiente

```powershell
docker exec juice-shop-nginx-edge-prova nginx -t
kubectl -n juiceshop get deployment,service,pods -o wide
curl.exe -sS -o NUL -w "HTTP=%{http_code}`n" -H "Host: juiceshop.local" http://127.0.0.1:8080/
curl.exe -k -sS -o NUL -w "HTTPS=%{http_code}`n" --resolve juiceshop.local:8443:127.0.0.1 https://juiceshop.local:8443/
```

Resultado esperado: Nginx válido, duas réplicas prontas, HTTP `301` e HTTPS `200`.

### Segurança

- As portas são publicadas somente em `127.0.0.1`.
- O certificado é autoassinado e destinado ao laboratório.
- Não exponha o Juice Shop vulnerável à internet.
- Não versione a chave privada nem arquivos temporários da prova.
- A prova isolada usa os nomes `juiceshop-prova` e `juice-shop-nginx-edge-prova`, evitando conflitos com o ambiente padrão.


## Implantação e validação

### 1. Verificar ferramentas

```powershell
docker --version
docker info
kind version
kubectl version --client
git --version
```

### 2. Verificar o cluster Kubernetes

```powershell
kubectl get nodes -o wide
kubectl get namespaces
kubectl -n juiceshop get deployment,service,pods -o wide
```

O resultado validado do Deployment foi de duas réplicas disponíveis. Os Pods devem estar em estado `Running` e prontos antes de testar a aplicação.

### 3. Verificar o Nginx Edge

```powershell
docker ps --filter "name=juice-shop-nginx-edge"
docker exec juice-shop-nginx-edge nginx -t
```

### 4. Testar HTTP e HTTPS

O HTTP deve redirecionar para HTTPS. O teste abaixo usa `-k` porque o certificado é autoassinado; isso serve para validar o laboratório, não para estabelecer confiança no certificado.

```powershell
curl.exe -sS -o NUL -w "HTTP=%{http_code}`n" http://juiceshop.local/
curl.exe -k -sS -o NUL -w "HTTPS=%{http_code}`n" https://juiceshop.local/
curl.exe -k -sS -D - -o NUL https://juiceshop.local/
```

Resultados observados: HTTP redirecionado com status `301`, HTTPS respondeu com `200`, e os cabeçalhos de segurança configurados foram apresentados na resposta.

### 5. Verificar limite de requisições

O Nginx está configurado com limite de 5 requisições por segundo, tolerância (`burst`) de 10 e resposta `429` para excesso de requisições. Em um teste de 40 solicitações, foram observadas 24 respostas `200` e 16 respostas `429`. Esse resultado é específico daquela execução.

### 6. Verificar a exposição local

As portas 80 e 443 do Nginx são vinculadas a `127.0.0.1`, e o NodePort 30080 não deve estar diretamente publicado no loopback do Windows. A validação anterior de `127.0.0.1:30080` retornou `False`.

```powershell
docker ps
Test-NetConnection 127.0.0.1 -Port 30080 -InformationLevel Quiet
```

## Certificado TLS

O certificado `nginx-edge/certs/juiceshop.local.crt` é autoassinado e possui SAN para `juiceshop.local` e `127.0.0.1`. Clientes que não confiam nele podem apresentar erro de validação. Não use `-k` como solução permanente para serviços reais.

A chave privada `nginx-edge/certs/juiceshop.local.key` é confidencial e deve permanecer fora do Git. O arquivo `.gitignore` contém regras para ignorar arquivos `.key` e `.pem` nesse diretório.

## Recuperação após recriar o cluster

O endereço do nó kind usado no `proxy_pass` do Nginx pode mudar se o cluster for recriado. Consulte o endereço atual e atualize `nginx-edge/nginx.conf` antes de recarregar o Nginx.

```powershell
kubectl get nodes -o wide
docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" juiceshop-local-control-plane
docker exec juice-shop-nginx-edge nginx -t
docker exec juice-shop-nginx-edge nginx -s reload
```

Confirme que o endereço usado no `proxy_pass` corresponde ao ambiente atual antes de executar o reload.

## Segurança e limites do laboratório

- O Juice Shop é intencionalmente vulnerável e deve ser usado apenas em ambiente autorizado.
- A configuração final documentada é local: o Nginx publica portas somente em `127.0.0.1`.
- O acesso externo foi desativado após a demonstração: encaminhamento de portas do roteador, regra `portproxy` do Windows e regras específicas de firewall para a porta 3000 foram removidos.
- O laboratório permaneceu disponível localmente para validação e gravação da demonstração.
- Não usar dados reais, credenciais pessoais ou senhas reutilizadas.
- O limite de requisições e os cabeçalhos HTTP são medidas complementares; não tornam o Juice Shop seguro para produção.
- O certificado autoassinado é apropriado apenas para o laboratório e não equivale a um certificado emitido por uma autoridade confiável.

## Evidências e documentação complementar

As capturas de tela das Etapas 2 a 6 estão em `docs/evidencias/`, organizadas por etapa. A pasta contém 108 imagens, distribuídas entre E2 (9), E3 (7), E4 (17), E5 (22) e E6 (53).

A evidência específica da Etapa 1 ainda deve ser localizada ou produzida, se for exigida na entrega. Não afirmar que existe uma captura que não foi localizada.

Documentos principais:

- `README.md`: guia geral do projeto.
- `ARQUITETURA-ETAPA6.md`: decisões, arquitetura, segurança, validações e limitações da Etapa 6.
- `docs/evidencias/`: capturas de tela de execução.

## Dificuldades e decisões

- A implantação inicial foi organizada com Docker e Docker Compose antes da evolução para Kubernetes com kind.
- O Nginx Edge foi adotado como ponto único de entrada HTTP/HTTPS local.
- O certificado autoassinado exigiu distinguir falha de confiança do certificado de falha de conectividade da aplicação.
- O endereço do nó kind pode mudar após recriação do cluster, exigindo revisão do upstream do Nginx.
- O limite de requisições foi validado com respostas HTTP `429` em teste controlado.
- O acesso externo foi desativado depois da demonstração para reduzir exposição desnecessária.

## Melhorias futuras

- Automatizar a descoberta do endereço do nó kind e a atualização do upstream.
- Automatizar os testes HTTP/HTTPS e a validação dos cabeçalhos.
- Produzir ou localizar a evidência pendente da Etapa 1.
- Revisar os arquivos de backup e manter apenas os artefatos necessários para a entrega.
- Demonstração em vídeo gravada e validada: docs/demonstracao/demonstracao-juice-shop.mp4.

## Encerramento e desmontagem

**Estado: teardown executado em 29/10/2026.**

Após a demonstração, o ambiente local foi desmontado. Foram removidos o contêiner Nginx Edge, o cluster Kind, os recursos do Docker Compose e sua rede. A entrada `juiceshop.local` também foi removida do arquivo `hosts`, e o cache DNS foi atualizado.

Comandos executados:

```powershell
docker rm -f juice-shop-nginx-edge
kind delete cluster --name juiceshop-local
docker compose down -v
```

A validação local posterior confirmou que não havia cluster Kind, containers do projeto, processos escutando nas portas 80, 443, 3000 e 30080, nem entrada `juiceshop.local` no arquivo `hosts`.

A exposição externa foi desativada após a demonstração. A validação local não substitui uma verificação independente das configurações do roteador.

## Estado da entrega

- **Etapas 1 a 6:** desenvolvidas e documentadas.
- **Etapa 7:** documentação revisada, vídeo de demonstração gravado e validações locais realizadas.
- **Repositório:** publicado no GitHub, na branch `master`. A revisão final e a publicação das evidências do teardown estão em andamento.
- **Demonstração:** `docs/demonstracao/demonstracao-juice-shop.mp4`, versionado via Git LFS.
- **Evidências:** capturas das Etapas 2 a 6 e registros finais disponíveis em `docs/evidencias/`. A evidência específica da Etapa 1 deve ser confirmada caso seja exigida.
- **Teardown:** concluído. Cluster Kind, containers do projeto, recursos do Docker Compose e rede foram removidos. A entrada `juiceshop.local` foi removida do arquivo `hosts`.
- **Validação local após o teardown:** nenhum cluster Kind encontrado, nenhum container do projeto listado, nenhuma das portas 80, 443, 3000 e 30080 em escuta e nenhuma entrada `juiceshop.local` no arquivo `hosts`.
- **Segurança:** o acesso externo foi desativado após a demonstração. A validação local não substitui uma verificação independente do roteador.
- **Reprodução por terceiros:** ainda não confirmada. Não afirmar que outra pessoa reproduziu o procedimento até que isso ocorra.
- **Revisão do histórico Git e das imagens:** conferir antes da publicação final para evitar exposição acidental de dados sensíveis.

## 9. Reprodução em clone limpo

A reprodução foi validada em um clone separado do repositório.

- Duas réplicas do Juice Shop ficaram prontas no Kubernetes `kind`.
- O Nginx foi conectado à rede Docker `kind`.
- O upstream usa o nome do nó, evitando um IP fixo:

```nginx
proxy_pass http://juiceshop-local-control-plane:30080;
```

- `nginx -t` passou.
- HTTP retornou `301` e HTTPS retornou `200`.
- As portas publicadas foram restritas a `127.0.0.1:80` e `127.0.0.1:443`.
- Os problemas de rede Docker e de incompatibilidade entre certificado e chave foram corrigidos.

Consulte `docs/evidencias/E9-reproducao-clone.md` para o registro do teste.

## 10. Segurança e encerramento

O Juice Shop é intencionalmente vulnerável e deve permanecer em laboratório autorizado. O acesso externo foi desativado após a demonstração. A chave privada local não deve ser versionada, e o NodePort `30080` não deve ser publicado diretamente no Windows.

O encerramento do ambiente original está registrado nos arquivos E7. A varredura Gitleaks está registrada em E8. A reprodução E9 foi realizada em um clone de teste e não significa que o ambiente original tenha sido alterado.

## 11. Pendências e melhorias

- Confirmar a evidência da Etapa 1, caso seja exigida.
- Automatizar a validação HTTP/HTTPS e dos cabeçalhos.
- Automatizar a verificação do upstream após recriar o cluster.
- Revisar os artefatos antes da publicação final.
