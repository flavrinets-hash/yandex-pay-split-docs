#!/usr/bin/env bash
# Статус заказа и список операций по нему.
# Использование: source env.sh && ./03-get-order.sh <orderId>
set -euo pipefail

curl --silent --show-error "$BASE_URL/v1/orders/$1" \
  --header "Authorization: Api-Key $API_KEY" \
  --header "X-Request-Id: $(uuidgen)"
echo
