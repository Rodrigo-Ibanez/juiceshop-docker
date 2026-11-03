# OWASP Juice Shop — Docker, Kubernetes e Nginx

## 1. Objetivo

Documentar a implantação e validação local do OWASP Juice Shop, evoluindo de Docker Compose para Kubernetes com kind e utilizando Nginx Edge como proxy reverso HTTPS.

O OWASP Juice Shop é intencionalmente vulnerável e destinado a treinamento. Utilize somente dados fictícios, credenciais descartáveis e ambientes autorizados. Não exponha a aplicação publicamente sem autorização e avaliação de risco.

## 2. Estado do projeto

- **Etapas 1 a 6:** implantação, evolução da arquitetura e validações realizadas.
- **Etapa 7:** documentação, revisão de segurança e consolidação das evidências.
- **Etapa 8:** publicação final e revisão do repositório público.

O ambiente original foi desmontado em 29/10/2026. Portanto, os resultados de execução descritos neste documento são registros históricos de validações realizadas antes do teardown.

A reprodução em um clone separado foi realizada em 29/10/2026 e está documentada em `evidencias/E9-reproducao-clone.md`.

## 3. Ambiente utilizado

Versões observadas durante a validação em 29/10/2026:

| Componente | Versão ou configuração |
|---|---|
| Sistema operacional | Windows 11 Pro, build 26200 |
| Docker Engine | 29.6.2 |
| Git | 2.55.0.windows.3 |
| kind | v0.33.0 |
| kubectl | v1.36.1 |
| Kubernetes do nó kind | v1.37.0 |
| Sistema operacional do nó | Debian GNU/Linux 13 |
| Réplicas do Juice Shop | 2 |
| Imagem da aplicação | `bkimminich/juice-shop:v20.3.0` |
| Nginx Edge | `nginx:1.28-alpine` |

As versões podem mudar em instalações futuras.

## 4. Arquitetura final

```text
Navegador no Windows
        |
        | https://juiceshop.local
        | 127.0.0.1:80 / 443
        v
Nginx Edge — Docker
        |
        | Rede Docker: kind
        | NodePort 30080
        v
Nó kind: juiceshop-local-control-plane
        |
        v
Service Kubernetes: juice-shop
        |
        v
Deployment: 2 réplicas
        |
        v
Pods OWASP Juice Shop — porta 3000
```

O hostname `juiceshop.local` é associado a `127.0.0.1` no arquivo `hosts` do Windows.

O Nginx Edge publica as portas 80 e 443 exclusivamente no loopback. O NodePort 30080 é acessado pela rede Docker `kind`, sem publicação direta dessa porta no Windows.

## 5. Responsabilidades das tecnologias

| Tecnologia | Responsabilidade neste projeto |
|---|---|
| Docker | Executa os contêineres e fornece a rede utilizada pelos componentes. |
| Docker Compose | Descreve a implantação inicial do Juice Shop e do Nginx nas Etapas 2 e 3. |
| kind | Cria um cluster Kubernetes local usando contêineres Docker como nós. |
| Kubernetes | Gerencia Deployment, Pods, réplicas, verificações de saúde e Service. |
| Nginx Edge | Centraliza o acesso HTTP/HTTPS, termina TLS, redireciona HTTP, aplica cabeçalhos, rate limit e registra requisições. |

Os arquivos Docker Compose representam a arquitetura inicial do projeto. A arquitetura final validada utiliza Kubernetes com kind e Nginx Edge independente.

## 6. Estrutura do repositório

```text
.
|-- README.md
|-- ARQUITETURA-ETAPA6.md
|-- .gitignore
|-- .gitattributes
|-- kind-config.yaml
|-- docker/
|   `-- docker-compose.yml
|-- nginx/
|   |-- nginx.conf
|   `-- edge/
|       |-- nginx.conf
|       `-- certs/
|           `-- juiceshop.local.crt
|-- k8s/
|   |-- namespace.yaml
|   |-- deployment.yaml
|   `-- service.yaml
|-- scripts/
|   `-- validar-juice-shop.ps1
|-- docs/
|   |-- etapas/
|   |   |-- etapa-1-ambiente-docker.md
|   |   |-- etapa-2-juice-shop-docker-compose.md
|   |   |-- etapa-3-nginx-proxy-reverso.md
|   |   |-- etapa-4-cluster-kubernetes-kind.md
|   |   |-- etapa-5-implantacao-kubernetes.md
|   |   `-- etapa-6-nginx-edge-https.md
|   `-- demonstracao/
|       `-- demonstracao-juice-shop.mp4
`-- evidencias/
```

A chave privada `nginx/edge/certs/juiceshop.local.key` deve ser gerada localmente e não deve ser versionada.

A pasta `prova-local/` contém arquivos específicos da reprodução de teste e é ignorada pelo Git. Ela não faz parte da configuração canônica do projeto.

## 7. Pré-requisitos para reprodução

- Windows com Docker Desktop em execução.
- PowerShell.
- Git.
- kind.
- kubectl.
- Acesso à internet para baixar as imagens necessárias.
- Permissão administrativa para editar o arquivo `hosts`.

Os comandos desta seção devem ser executados na raiz do repositório.

## 8. Reprodução da arquitetura padrão

### 8.1. Conferir as ferramentas

```powershell
docker --version
docker info
git --version
kind version
kubectl version --client
```

### 8.2. Criar o cluster kind

O arquivo `kind-config.yaml` define o cluster `juiceshop-local`.

```powershell
kind create cluster --config .\kind-config.yaml
kubectl wait --for=condition=Ready nodes --all --timeout=180s
kubectl get nodes -o wide
```

### 8.3. Implantar o Juice Shop

```powershell
kubectl apply -f .\k8s\namespace.yaml
kubectl apply -f .\k8s\deployment.yaml
kubectl apply -f .\k8s\service.yaml

kubectl -n juiceshop rollout status deployment/juice-shop --timeout=300s
kubectl -n juiceshop get deployment,service,pods -o wide
```

Confirme que as duas réplicas estão disponíveis e que os Pods estão prontos antes de continuar.

### 8.4. Gerar o certificado TLS local

A chave privada deve permanecer no computador e fora do Git.

Gere o certificado e a chave juntos, no mesmo comando, para garantir que pertençam ao mesmo par:

```powershell
New-Item -ItemType Directory -Force .\nginx\edge\certs | Out-Null

docker run --rm `
  -v "${PWD}\nginx\edge\certs:/certs" `
  alpine/openssl req -x509 -nodes -days 365 -newkey rsa:2048 `
  -keyout /certs/juiceshop.local.key `
  -out /certs/juiceshop.local.crt `
  -subj "/CN=juiceshop.local" `
  -addext "subjectAltName=DNS:juiceshop.local,IP:127.0.0.1"
```

Antes de iniciar o Nginx, confira se o certificado e a chave correspondem:

```powershell
$certModulus = docker run --rm -v "${PWD}\nginx\edge\certs:/certs" alpine/openssl x509 -noout -modulus -in /certs/juiceshop.local.crt
$keyModulus = docker run --rm -v "${PWD}\nginx\edge\certs:/certs" alpine/openssl rsa -noout -modulus -in /certs/juiceshop.local.key

if ($certModulus -ne $keyModulus) {
    throw "O certificado e a chave privada não correspondem."
}

Write-Host "OK: certificado e chave correspondem."
```

Não compartilhe nem versione o arquivo `.key`.

### 8.5. Configurar o hostname local

Abra o PowerShell como administrador e execute:

```powershell
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
Add-Content -Path $hostsPath -Value "`n127.0.0.1 juiceshop.local"
ipconfig /flushdns
```

Se a entrada já existir, não a duplique.

### 8.6. Iniciar o Nginx Edge

A configuração versionada em `nginx/edge/nginx.conf` utiliza o upstream:

```nginx
proxy_pass http://juiceshop-local-control-plane:30080;
```

O contêiner Nginx precisa estar conectado à rede Docker `kind`.

```powershell
docker run -d `
  --name juice-shop-nginx-edge `
  --network kind `
  -p 127.0.0.1:80:80 `
  -p 127.0.0.1:443:443 `
  -v "${PWD}\nginx\edge\nginx.conf:/etc/nginx/nginx.conf:ro" `
  -v "${PWD}\nginx\edge\certs:/etc/nginx/certs:ro" `
  nginx:1.28-alpine
```

Valide a configuração e confira o estado do contêiner:

```powershell
docker exec juice-shop-nginx-edge nginx -t
docker ps --filter "name=juice-shop-nginx-edge"
```

O primeiro comando deve apresentar `syntax is ok` e `test is successful`.

### 8.7. Validar HTTP e HTTPS

```powershell
curl.exe -sS -o NUL -w "HTTP=%{http_code}`n" http://juiceshop.local/
curl.exe -k -sS -o NUL -w "HTTPS=%{http_code}`n" https://juiceshop.local/
curl.exe -k -sS -D - -o NUL https://juiceshop.local/
```

Resultados esperados:

- HTTP: `301`, redirecionando para HTTPS.
- HTTPS: `200`, com a aplicação respondendo.
- O certificado autoassinado pode gerar aviso de confiança no navegador. O parâmetro `-k` é utilizado apenas nos testes locais para ignorar essa validação.

### 8.8. Executar a validação automatizada

```powershell
.\scripts\validar-juice-shop.ps1
```

O script verifica cluster, réplicas, contêiner Nginx, sintaxe, upstream, portas publicadas, redirecionamento, HTTPS e cabeçalhos de segurança.

O resultado registrado na execução documentada foi de 12 testes aprovados e nenhum reprovado. Consulte `evidencias/E10-validacao-automatica.txt`.

## 9. Reconstrução do ambiente do zero

Este procedimento permite reconstruir a arquitetura da Fase 2 em uma instalação limpa do Windows. Ele utiliza Docker Desktop, WSL 2, kind, Kubernetes e Nginx Edge.

**Atenção:** execute este procedimento em um ambiente limpo e isolado. Ele utiliza os nomes de cluster `juiceshop-local` e contêiner `juice-shop-nginx-edge`. Não execute sobre um laboratório que já utilize esses recursos.

### 1. Pré-requisitos

- Windows 10 ou 11 de 64 bits atualizado.
- Virtualização habilitada na BIOS/UEFI.
- Permissão de administrador no Windows.
- Windows Package Manager (`winget`).
- Conexão com a internet.
- Espaço em disco e memória suficientes para Docker Desktop, Kubernetes e duas réplicas da aplicação.

Abra o PowerShell como administrador.

Confira o gerenciador de pacotes:

    winget --version

Instale ou atualize o WSL:

    wsl --install
    wsl --update
    wsl --set-default-version 2

Se o Windows solicitar reinicialização, reinicie antes de continuar. Depois, abra novamente o PowerShell.

### 2. Instalar as ferramentas

Instale PowerShell 7, Git, Docker Desktop, kubectl e kind:

    winget install --id Microsoft.PowerShell -e
    winget install --id Git.Git -e
    winget install --id Docker.DockerDesktop -e
    winget install --id Kubernetes.kubectl -e
    winget install --id Kubernetes.kind -e

Feche e abra novamente o terminal para atualizar o PATH.

Abra o Docker Desktop. Aguarde o mecanismo Docker iniciar e habilite o uso do mecanismo baseado em WSL 2 nas configurações do Docker Desktop.

Confira as ferramentas:

    pwsh --version
    git --version
    docker --version
    kind version
    kubectl version --client
    wsl --status

Confirme que o Docker está usando contêineres Linux:

    docker info --format 'Sistema de contêineres: {{.OSType}}'

O resultado esperado é `linux`. Se aparecer `windows`, corrija a configuração do Docker Desktop antes de continuar.

Confirme também que o mecanismo está acessível:

    docker info

### 3. Obter o projeto

Clone o repositório:

    git clone https://github.com/Rodrigo-Ibanez/juiceshop-docker.git
    Set-Location .\juiceshop-docker

Confirme que está na raiz do projeto:

    Get-Location
    Get-ChildItem

Os comandos seguintes devem ser executados a partir dessa pasta.

### 4. Verificar se o ambiente está livre

Antes de criar recursos, verifique se os nomes utilizados já existem:

    kind get clusters
    docker ps -a

Se já existir um cluster chamado `juiceshop-local`, não prossiga com a criação. Se já existir um contêiner chamado `juice-shop-nginx-edge`, não prossiga com a criação do Nginx.

Não remova recursos existentes sem identificar a qual etapa ou laboratório pertencem.

### 5. Gerar o certificado HTTPS

Crie um certificado autoassinado para o endereço local:

    New-Item -ItemType Directory -Force .\nginx\edge\certs
    $rsa = [System.Security.Cryptography.RSA]::Create(2048)
    $request = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new('CN=juiceshop.local', $rsa, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
    $san = [System.Security.Cryptography.X509Certificates.SubjectAlternativeNameBuilder]::new()
    $san.AddDnsName('juiceshop.local')
    $san.AddIpAddress([System.Net.IPAddress]::Parse('127.0.0.1'))
    $request.CertificateExtensions.Add($san.Build())
    $cert = $request.CreateSelfSigned([DateTimeOffset]::Now.AddMinutes(-5), [DateTimeOffset]::Now.AddDays(365))
    [IO.File]::WriteAllText((Join-Path $PWD 'nginx/edge/certs/juiceshop.local.crt'), $cert.ExportCertificatePem())
    [IO.File]::WriteAllText((Join-Path $PWD 'nginx/edge/certs/juiceshop.local.key'), $rsa.ExportPkcs8PrivateKeyPem())
    $rsa.Dispose()

Importe o certificado na autoridade raiz confiável do usuário atual:

    Import-Certificate -FilePath .\nginx\edge\certs\juiceshop.local.crt -CertStoreLocation Cert:\CurrentUser\Root

A chave privada `juiceshop.local.key` é gerada localmente. Ela não deve ser versionada, compartilhada ou enviada ao Git. O `.gitignore` do projeto já contém regra para ignorar essa chave.

### 6. Configurar o endereço local

Abra o Bloco de Notas como administrador:

    notepad C:\Windows\System32\drivers\etc\hosts

Adicione a seguinte linha, caso ainda não exista:

    127.0.0.1 juiceshop.local

Salve o arquivo e atualize o cache DNS:

    ipconfig /flushdns

Confira a resolução:

    ping juiceshop.local

O endereço deve resolver para `127.0.0.1`.

### 7. Criar o cluster Kubernetes

Confira novamente se o cluster de destino não existe:

    kind get clusters

Se `juiceshop-local` já estiver listado, pare e identifique o ambiente antes de continuar.

Crie o cluster:

    kind create cluster --config .\kind-config.yaml

Selecione o contexto:

    kubectl config use-context kind-juiceshop-local

Valide o nó:

    kubectl get nodes -o wide

O arquivo `kind-config.yaml` define um cluster chamado `juiceshop-local` com um nó `control-plane`.

### 8. Baixar e carregar a imagem

Baixe a imagem utilizada pelo Deployment:

    docker pull bkimminich/juice-shop:v20.3.0

Carregue a imagem no cluster:

    kind load docker-image bkimminich/juice-shop:v20.3.0 --name juiceshop-local

### 9. Implantar o Juice Shop

Crie o namespace:

    kubectl apply -f .\k8s\namespace.yaml

Aplique o Deployment e o Service específicos da Fase 2:

    kubectl apply -f .\k8s\fase2\deployment.yaml
    kubectl apply -f .\k8s\fase2\service.yaml

Aguarde as réplicas ficarem disponíveis:

    kubectl -n juiceshop rollout status deployment/juice-shop --timeout=180s

Confira os recursos:

    kubectl -n juiceshop get deployment
    kubectl -n juiceshop get pods -o wide
    kubectl -n juiceshop get service

O Deployment deve apresentar duas réplicas disponíveis. Os Pods devem estar `Running` e prontos.

O Service utiliza NodePort `30080` dentro do nó do kind. Essa porta não deve ser publicada diretamente no Windows.

### 10. Iniciar o Nginx Edge

A configuração utilizada nesta etapa é `nginx/edge/nginx-fase2.conf`.

Ela encaminha as requisições para `juiceshop-local-control-plane:30080` pela rede Docker `kind`.

Confirme que o contêiner ainda não existe:

    docker ps -a --filter "name=^/juice-shop-nginx-edge$"

Se não houver conflito, execute na raiz do repositório:

    $repo = (Resolve-Path .).Path.Replace('\', '/')
    docker run -d --name juice-shop-nginx-edge --network kind -p 127.0.0.1:80:80 -p 127.0.0.1:443:443 --mount "type=bind,source=$repo/nginx/edge/nginx-fase2.conf,target=/etc/nginx/nginx.conf,readonly" --mount "type=bind,source=$repo/nginx/edge/certs,target=/etc/nginx/certs,readonly" nginx:1.28-alpine

As portas HTTP e HTTPS são publicadas exclusivamente em `127.0.0.1`. Não publique o NodePort diretamente e não configure encaminhamento de portas no roteador.

### 11. Validar a implantação

Valide a configuração do Nginx:

    docker exec juice-shop-nginx-edge nginx -t

Confira o contêiner e as portas publicadas:

    docker ps

Confira os recursos Kubernetes:

    kubectl -n juiceshop get deployment,pods,service

Teste o redirecionamento HTTP:

    curl.exe -I http://juiceshop.local/

O resultado esperado é HTTP `301`, redirecionando para HTTPS.

Teste HTTPS:

    curl.exe -I https://juiceshop.local/

O resultado esperado é HTTP `200`. O certificado deve estar confiável no perfil atual do Windows.

Se o teste de HTTPS falhar por confiança do certificado, confira a importação no repositório `Cert:\CurrentUser\Root`. Como diagnóstico temporário, é possível testar a conexão com `curl.exe -k -I https://juiceshop.local/`; essa opção ignora a validação do certificado e não deve ser tratada como correção permanente.

Confira também o limite de exposição:

    Test-NetConnection 127.0.0.1 -Port 80
    Test-NetConnection 127.0.0.1 -Port 443
    Test-NetConnection 127.0.0.1 -Port 30080

As portas 80 e 443 devem aceitar conexões locais. A porta 30080 não deve estar publicada diretamente no loopback do Windows.

### 12. Verificações de segurança

- Confirmar que as portas 80 e 443 estão vinculadas somente a `127.0.0.1`.
- Confirmar que o NodePort `30080` não está publicado diretamente no Windows.
- Não configurar encaminhamento de portas no roteador.
- Não utilizar dados reais ou credenciais pessoais.
- Não versionar a chave privada TLS.
- Não utilizar o Juice Shop em produção.
- Manter o laboratório restrito a ambiente local e autorizado.

### 13. Recuperação e desmontagem

Se o cluster for recriado, confira o nome e o endereço do nó:

    kind get clusters
    docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" juiceshop-local-control-plane

A configuração Nginx desta etapa utiliza o nome DNS do contêiner do nó kind. Não substitua esse destino por um IP sem necessidade.

Para desmontar esta implantação, confirme primeiro que está no ambiente isolado da Fase 2 e que os recursos não pertencem à Fase 3.

Remova somente os recursos desta implantação:

    docker rm -f juice-shop-nginx-edge
    kind delete cluster --name juiceshop-local

A remoção do cluster exclui os recursos Kubernetes nele existentes. Não execute esses comandos em um ambiente compartilhado ou enquanto houver atividades de outra etapa.

Se desejar remover a entrada local, edite como administrador o arquivo `C:\Windows\System32\drivers\etc\hosts`, remova somente a linha `127.0.0.1 juiceshop.local` e execute:

    ipconfig /flushdns

A remoção do certificado confiável do usuário é opcional. Faça isso somente identificando o certificado correto pelo thumbprint antes de removê-lo.

## 10. Segurança e limites

- O Juice Shop é intencionalmente vulnerável.
- As portas do Nginx devem ser publicadas somente em `127.0.0.1`.
- O NodePort 30080 não deve ser publicado diretamente no Windows.
- A chave privada TLS não deve ser versionada.
- O certificado autoassinado é destinado ao laboratório.
- Os cabeçalhos de segurança e o rate limit são proteções complementares; não tornam a aplicação segura para produção.
- Não utilizar dados reais, credenciais pessoais ou senhas reutilizadas.

A configuração de rate limit registrada utiliza 5 requisições por segundo, `burst` de 10 e resposta HTTP 429 quando o limite é excedido.

Em um teste documentado de 40 solicitações, foram observadas 24 respostas HTTP 200 e 16 respostas HTTP 429. Esse resultado corresponde àquela execução específica.

### Exposição externa

Na Fase 1, o acesso externo foi configurado para a demonstração autorizada. Após a demonstração, foram removidos o encaminhamento de portas do roteador, a regra `portproxy` do Windows e regras específicas do Firewall relacionadas à porta 3000.

A Fase 2 foi mantida sem exposição externa. A validação local não substitui uma verificação independente das configurações do roteador.

## 11. Reprodução em clone limpo

Em 29/10/2026, foram documentadas duas reproduções em clones separados, com objetivos e configurações distintos.

### E9 — Reprodução da arquitetura padrão

A reprodução E9 utilizou a arquitetura padrão do projeto:

- Clone Git concluído.
- Namespace, Deployment e Service criados.
- Duas réplicas do Juice Shop prontas.
- Nginx conectado à rede Docker `kind`.
- Sintaxe do Nginx validada.
- HTTP retornou 301.
- HTTPS retornou 200.
- Portas publicadas somente em `127.0.0.1:80` e `127.0.0.1:443`.
- Upstream resolvido pelo nome `juiceshop-local-control-plane`.

Durante o teste foram corrigidos problemas de conectividade entre o Nginx e a rede `kind`, além de uma incompatibilidade entre o certificado e a chave privada.

Registro: `evidencias/E9-reproducao-clone.md`.

### E11 — Prova isolada de reprodução a partir do README

A E11 utilizou um cluster de teste separado, denominado `juiceshop-prova`, para preservar a configuração padrão do projeto.

Características específicas dessa prova:

- Cluster kind: `juiceshop-prova`.
- Upstream do Nginx: `juiceshop-prova-control-plane:30080`.
- Portas publicadas no host: `127.0.0.1:8080` e `127.0.0.1:8443`.
- Portas internas do Nginx: 80 e 443.
- HTTP retornou 301.
- HTTPS retornou 200.
- Duas réplicas do Juice Shop disponíveis.
- Configuração do Nginx validada com `nginx -t`.

A configuração específica da prova está em `prova-local/` e é ignorada pelo Git. Ela não deve substituir `kind-config.yaml` nem `nginx/edge/nginx.conf`.

Registro: `evidencias/E11-prova-clone-readme.md`.

As reproduções E9 e E11 foram realizadas pelo responsável pelo projeto. Não representam uma reprodução independente por terceiro.

## 12. Dificuldades e decisões

- **NodePort:** o acesso direto pelo loopback do Windows não estava disponível. O Nginx foi conectado à rede Docker `kind` para alcançar o NodePort.
- **Upstream:** a configuração definitiva utiliza o nome DNS `juiceshop-local-control-plane`, evitando a dependência de um IP fixo.
- **Certificado TLS:** o certificado autoassinado gera aviso de confiança nos clientes que não o reconhecem.
- **Logs:** foi necessário localizar os arquivos internos da aplicação e correlacioná-los com os registros do Nginx.
- **Rate limit:** foram realizados testes controlados para observar as respostas HTTP 429.
- **Exposição externa:** o acesso foi desativado após a demonstração para reduzir a exposição desnecessária.

## 13. O que faria diferente

Automatizaria a criação do cluster, a conexão do Nginx à rede Docker, a geração do certificado local e as verificações de disponibilidade do upstream.

Um Ingress Controller poderia ser avaliado em um ambiente com múltiplas aplicações ou necessidade de roteamento mais declarativo. Ele não foi necessário para o escopo deste laboratório.

## 14. Evidências e documentação complementar

As evidências visuais das Etapas 2 a 6 estão em `evidencias/`. O inventário atual contém 108 imagens:

| Etapa | Imagens |
|---|---:|
| Etapa 2 | 9 |
| Etapa 3 | 7 |
| Etapa 4 | 17 |
| Etapa 5 | 22 |
| Etapa 6 | 53 |
| **Total** | **108** |

A evidência específica da Etapa 1 ainda deve ser localizada ou produzida, caso seja exigida na entrega. Não afirmar que existe uma captura que não foi localizada.

### Documentação individual das etapas

Os registros individuais de execução estão em `docs/etapas/`:

- `docs/etapas/etapa-1-ambiente-docker.md`
- `docs/etapas/etapa-2-juice-shop-docker-compose.md`
- `docs/etapas/etapa-3-nginx-proxy-reverso.md`
- `docs/etapas/etapa-4-cluster-kubernetes-kind.md`
- `docs/etapas/etapa-5-implantacao-kubernetes.md`
- `docs/etapas/etapa-6-nginx-edge-https.md`

### Outros registros

- `ARQUITETURA-ETAPA6.md`: arquitetura, decisões, segurança, validações e limitações da Etapa 6.
- `evidencias/E7-estado-antes-teardown.txt`: estado do ambiente antes da desmontagem.
- `evidencias/E7-teardown-final.txt`: registro do teardown.
- `evidencias/E8-gitleaks-atual.txt`: registro mais recente da varredura Gitleaks, incluindo a análise do histórico Git e dos arquivos destinados à publicação.
- `evidencias/E8-gitleaks.txt`: registro anterior da varredura Gitleaks.
- `evidencias/E8-gitleaks-resultado.png`: captura do resultado da varredura.
- `evidencias/E9-reproducao-clone.md`: reprodução da arquitetura padrão em clone separado.
- `evidencias/E10-validacao-automatica.txt`: resultado da validação automatizada.
- `evidencias/E11-prova-clone-readme.md`: relatório da reprodução isolada em clone separado.
- `evidencias/E11-prova-clone-readme.png`: captura da prova de reprodução.
- `docs/demonstracao/demonstracao-juice-shop.mp4`: vídeo de demonstração, versionado com Git LFS.

## 15. Teardown — desmontagem do ambiente

O teardown do ambiente original foi executado em 29/10/2026.

Comandos registrados:

```powershell
docker rm -f juice-shop-nginx-edge
kind delete cluster --name juiceshop-local
docker compose -f .\docker\docker-compose.yml down -v
```

A entrada `juiceshop.local` foi removida do arquivo `hosts` e o cache DNS foi atualizado.

O registro posterior informou:

- Nenhum cluster kind encontrado.
- Nenhum contêiner do projeto em execução.
- Nenhum recurso do Docker Compose listado.
- Nenhum processo escutando nas portas 80, 443, 3000 e 30080.
- Nenhuma entrada `juiceshop.local` no arquivo `hosts`.
- Exposição externa desativada após a demonstração.

Consulte `evidencias/E7-teardown-final.txt`. A verificação local não substitui a conferência independente do roteador.

## 16. Estado da entrega e pendências

- **Etapas 1 a 6:** desenvolvidas e documentadas.
- **Etapa 7:** documentação e evidências em revisão e consolidação.
- **Etapa 8:** publicação final no GitHub ainda pendente de revisão e sincronização dos commits locais.
- **Teardown:** executado e registrado.
- **Validação automatizada:** resultado registrado em E10.
- **Gitleaks:** varredura local do histórico Git sem segredos detectados, conforme registro E8. Reexecutar antes da publicação final.
- **Clone limpo:** reproduções E9 e E11 realizadas pelo responsável pelo projeto; não houve confirmação de reprodução independente por terceiro.
- **Etapa 1:** confirmar se a evidência específica é exigida e se existe captura correspondente.
- **Documentação por etapa:** seis documentos individuais criados em `docs/etapas/`; revisão de consistência com o README ainda pendente.
- **Revisão de segurança:** revisar arquivos, capturas, histórico Git e referências antes da publicação final.

Não considerar a Etapa 8 concluída até que a revisão final seja aprovada e os commits locais sejam publicados no GitHub.
