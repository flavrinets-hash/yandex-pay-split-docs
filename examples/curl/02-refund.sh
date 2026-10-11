#!/usr/bin/env bash
# Полный возврат заказа.
# Использование: source env.sh && ./02-refund.sh <orderId> <сумма>
set -euo pipefail

ORDER_ID="$1"
AMOUNT="$2"

curl --silent --show-error "$BASE_URL/v2/orders/$ORDER_ID/refund" \
  --header "Authorization: Api-Key $API_KEY" \
  --header "X-Request-Id: $(uuidgen)" \
  --header "Content-Type: application/json" \
  --data "{\"externalOperationId\": \"$(uuidgen)\", \"refundAmount\": \"$AMOUNT\"}"
echo
