\# Fase 3 — Burp Suite Community e interceptação HTTPS



\## 1. Objetivo



Configurar o Burp Suite Community como proxy de interceptação para analisar o tráfego HTTP e HTTPS entre o navegador Microsoft Edge e o OWASP Juice Shop no ambiente de laboratório.



\## 2. Ferramentas utilizadas



\- Burp Suite Community Edition.

\- Microsoft Edge, com perfil isolado para o laboratório.

\- OWASP Juice Shop.

\- Certificado da autoridade certificadora PortSwigger CA.



\## 3. Configuração do proxy



Listener configurado no Burp Suite:



\- Endereço: `127.0.0.1`

\- Porta: `8080`

\- Protocolo: HTTP proxy.



O navegador foi iniciado com um perfil separado e direcionamento explícito para o proxy:



```cmd

msedge.exe --user-data-dir="%LOCALAPPDATA%\\Edge-LAB-PENTEST" --proxy-server="http://127.0.0.1:8080" --no-first-run

```



O caminho do perfil foi validado em `edge://version`.



\## 4. Validação HTTP



Foi realizado acesso ao endereço:



`http://neverssl.com`



O Burp Suite registrou a requisição no HTTP history e apresentou resposta HTTP 200.



Essa validação confirmou a comunicação entre o navegador, o proxy e o servidor de destino.



\## 5. Configuração da confiança HTTPS



No primeiro acesso ao Juice Shop por HTTPS, o navegador apresentou:



`net::ERR\_CERT\_AUTHORITY\_INVALID`



O comportamento ocorreu porque o navegador ainda não confiava na autoridade certificadora utilizada pelo Burp Suite.



Foi exportado o certificado `burp-ca.der` pela interface do Burp Suite e importado no repositório de certificados do Windows:



`Usuário Atual → Autoridades de Certificação Raiz Confiáveis → Certificados`



Certificado instalado: `PortSwigger CA`.



Após a instalação, o navegador passou a confiar nos certificados apresentados pelo Burp durante a interceptação HTTPS.



\## 6. Funcionamento da interceptação HTTPS



O Burp Suite atua como intermediário entre o navegador e o servidor.



A comunicação ocorre em duas conexões TLS:



1\. Navegador com o Burp Suite.

2\. Burp Suite com o servidor de destino.



A autoridade certificadora do Burp permite que o navegador valide os certificados gerados pelo proxy durante a inspeção do tráfego HTTPS.



Essa configuração permite analisar requisições e respostas sem desativar a validação de certificados do navegador.



\## 7. Interceptação no OWASP Juice Shop



Aplicação acessada:



`https://juiceshop.local`



Com a interceptação habilitada, foi capturada uma requisição:



\- Método: `POST`

\- Endpoint: `/socket.io/?EIO=4\&transport=polling`

\- Host: `juiceshop.local`

\- Origem: `https://juiceshop.local`

\- Content-Type: `text/plain;charset=UTF-8`



A requisição pertencia à comunicação Socket.IO utilizada pela aplicação.



Foram identificados e analisados:



\- Método e caminho HTTP.

\- Cabeçalho Host.

\- Cookie de idioma.

\- User-Agent.

\- Origin e Referer.

\- Content-Type e Content-Length.

\- Corpo da requisição.



A opção Forward foi utilizada para liberar as requisições interceptadas e restabelecer o funcionamento normal da aplicação.



\## 8. Evidências



As capturas desta atividade estão armazenadas em `docs/evidencias/F3-E0/`.



\- `F3-E0-09-burp-proxy-listener.png` — listener do Burp ativo em 127.0.0.1:8080.

\- `F3-E0-10-burp-ca-confiavel.png` — PortSwigger CA no repositório de autoridades confiáveis.

\- `F3-E0-11-burp-interceptacao-https.png` — requisição HTTPS do Juice Shop interceptada.



\## 9. Segurança e cuidados



\- O Burp Suite foi utilizado exclusivamente no laboratório autorizado.

\- A autoridade certificadora PortSwigger CA foi instalada para permitir a inspeção HTTPS.

\- A confiança nessa CA permite que o Burp apresente certificados aceitos pelo navegador e, portanto, deve ser restrita ao ambiente de teste.

\- A CA deve ser removida do repositório de certificados do Windows ao encerrar a atividade.

\- Excluir o perfil isolado do Edge não remove o certificado instalado no repositório do Windows.

\- A interceptação deve permanecer desativada quando não estiver sendo utilizada.



\## 10. Resultado



A configuração foi validada com sucesso:



\- Proxy local do Burp ativo.

\- Tráfego HTTP registrado.

\- Certificado PortSwigger CA instalado e reconhecido pelo navegador.

\- Acesso HTTPS ao Juice Shop sem erro de confiança.

\- Requisição HTTPS interceptada e analisada.

\- Requisições liberadas com Forward e aplicação funcionando normalmente.



\*\*Status:\*\* atividade prática concluída. Remoção da PortSwigger CA permanece como procedimento obrigatório de encerramento do laboratório.

