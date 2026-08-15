#!/usr/bin/env bash
# Exemplo ilustrativo simplificado do processo de cutover blue/green
# descrito no README. Genérico, adaptar nomes de serviço/porta pro
# seu próprio ambiente — não é a receita literal usada em produção.

set -euo pipefail

AMBIENTE_ATUAL="blue"
AMBIENTE_NOVO="green"
PORTA_VALIDACAO=8081
PORTA_PRODUCAO=8080
JANELA_FALLBACK_HORAS=48

echo "=== 1. Subindo ambiente '$AMBIENTE_NOVO' em paralelo, porta de validação ==="
docker compose -f "docker-compose.${AMBIENTE_NOVO}.yml" up -d

echo "=== 2. Aguardando health check do novo ambiente ==="
for i in $(seq 1 30); do
  if curl -fsS "http://localhost:${PORTA_VALIDACAO}/health" >/dev/null 2>&1; then
    echo "OK - ambiente novo saudável após ${i}0s"
    break
  fi
  sleep 10
done

echo "=== 3. Rodando migração de schema (idempotente, cobre versões intermediárias) ==="
docker compose -f "docker-compose.${AMBIENTE_NOVO}.yml" exec -T app ./migrate.sh --to-latest

echo "=== 4. Validação manual pendente ==="
echo "Acesse http://localhost:${PORTA_VALIDACAO} e confirme antes de prosseguir."
read -r -p "Ambiente novo validado? Prosseguir com o corte? [s/N] " confirmacao
[ "$confirmacao" = "s" ] || { echo "Abortado. Ambiente '$AMBIENTE_NOVO' segue em paralelo pra nova tentativa."; exit 1; }

echo "=== 5. Cutover: redirecionando porta de produção ==="
# Troca de porta via proxy reverso, não reinício do serviço em si -> sem downtime
sed -i "s/proxy_pass .*/proxy_pass http:\/\/localhost:${PORTA_VALIDACAO};/" /etc/nginx/sites-enabled/app.conf
nginx -s reload

echo "=== 6. Mantendo '$AMBIENTE_ATUAL' como fallback por ${JANELA_FALLBACK_HORAS}h ==="
echo "docker compose -f docker-compose.${AMBIENTE_ATUAL}.yml down" | at now + ${JANELA_FALLBACK_HORAS} hours

echo "Cutover concluído. Fallback agendado — rollback manual disponível até lá."
