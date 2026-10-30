# Evidência — Reprodução em clone limpo

Data: 29/10/2026
Repositório: https://github.com/Rodrigo-Ibanez/juiceshop-docker
Ambiente: Windows, Docker Desktop, kind, Kubernetes e Nginx.

## Resultado validado
- Clone Git concluído.
- Namespace, Deployment e Service criados.
- Duas réplicas do Juice Shop em execução.
- Nginx validado com `nginx -t`.
- HTTP retornou `301`.
- HTTPS retornou `200`.
- Portas publicadas somente em `127.0.0.1:80` e `127.0.0.1:443`.
- Upstream do Nginx validado pelo nome `juiceshop-local-control-plane` na rede Docker `kind`.

## Problemas identificados e resolvidos
1. O Nginx inicialmente não alcançava o NodePort porque estava fora da rede Docker `kind`.
2. O certificado e a chave privada não correspondiam, impedindo a inicialização do Nginx.
3. O Nginx foi recriado diretamente na rede `kind` e foi gerado um novo par local de certificado e chave.
4. Após as correções, `nginx -t` passou, HTTP retornou `301` e HTTPS retornou `200`.

## Segurança
O acesso externo permaneceu desabilitado. A chave privada é local e ignorada pelo Git. Esta evidência documenta o teste no clone; não afirma que o ambiente de produção foi alterado.
