# E11 — Prova de reprodução a partir do README

Data: 29/10/2026
Repositório: https://github.com/Rodrigo-Ibanez/juiceshop-docker
Clone de prova: C:\Users\Adm\Desktop\juiceshop-prova-readme
Cluster: juiceshop-prova

## Resultados

- Deployment Juice Shop: 2/2 réplicas disponíveis.
- Pods: ambos em execução.
- Nginx: configuração validada com `nginx -t`.
- HTTP: 301.
- HTTPS: 200.
- Portas publicadas apenas em 127.0.0.1:8080 e 127.0.0.1:8443.
- A prova usou um cluster separado para preservar o ambiente original.

## Evidência

Captura: `E11-prova-clone-readme.png`

## Segurança

- O serviço permaneceu acessível somente localmente.
- A chave privada TLS não deve ser versionada.
- A configuração específica do cluster de prova não deve substituir a configuração padrão.
