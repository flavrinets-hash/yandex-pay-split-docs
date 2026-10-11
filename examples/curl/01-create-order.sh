#!/usr/bin/env bash
# Создание заказа с оплатой картой или Сплитом.
# Использование: source env.sh && ./01-create-order.sh
set -euo pipefail

ORDER_ID="${ORDER_ID:-$(uuidgen)}"
echo "orderId: $ORDER_ID" >&2

curl --silent --show-error "$BASE_URL/v1/orders" \
  --header "Authorization: Api-Key $API_KEY" \
  --header "X-Request-Id: $(uuidgen)" \
  --header "Content-Type: application/json" \
  --data @- <<JSON
{
  "orderId": "$ORDER_ID",
  "currencyCode": "RUB",
  "availablePaymentMethods": ["CARD", "SPLIT"],
  "preferredPaymentMethod": "SPLIT",
  "cart": {
    "items": [
      {
        "productId": "Item_1",
        "title": "Тестовый товар",
        "unitPrice": "30000.00",
        "discountedUnitPrice": "30000.00",
        "total": "30000.00",
        "quantity": { "count": "1" }
      }
    ],
    "total": { "amount": "30000.00" }
  },
  "redirectUrls": {
    "onSuccess": "https://example.com/success",
    "onError": "https://example.com/error"
  }
}
JSON
echo
