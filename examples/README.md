# Примеры запросов

Запросы и ответы тестовой среды Яндекс Пэй (Sandbox). Ключи и идентификаторы магазина заменены на `<MERCHANT_ID>`.

## Логи прогона

Сценарий «создание заказа → оплата Сплитом → полный возврат», выполнен 10 октября 2026 года.

| Файл | Запрос | Результат |
| --- | --- | --- |
| [`logs/01-create-order.json`](logs/01-create-order.json) | `POST /v1/orders` | Заказ создан, получен `paymentUrl` |
| [`logs/02-refund.json`](logs/02-refund.json) | `POST /v2/orders/{order_id}/refund` | Возврат принят, операция `REFUND` в статусе `PENDING` |
| [`logs/03-get-order.json`](logs/03-get-order.json) | `GET /v1/orders/{order_id}` | Заказ `REFUNDED`, операции `AUTHORIZE` и `REFUND` в статусе `SUCCESS` |

## curl-скрипты

```bash
cd examples/curl
cp env.example env.sh        # впишите свой merchantId
source env.sh
./01-create-order.sh         # выведет orderId и paymentUrl
# оплатите заказ по paymentUrl в браузере
./02-refund.sh <orderId> 30000.00
./03-get-order.sh <orderId>
```
