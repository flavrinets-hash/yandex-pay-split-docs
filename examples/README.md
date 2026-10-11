# Примеры запросов

Запросы и ответы тестовой среды Яндекс Пэй (Sandbox). Ключи и идентификаторы магазина заменены на `<MERCHANT_ID>`.

## Логи прогона

Сценарий «создание заказа → оплата Сплитом → полный возврат», выполнен 10 октября 2026 года.

| Файл | Запрос | Результат |
| --- | --- | --- |
| [`logs/01-create-order.json`](logs/01-create-order.json) | `POST /v1/orders` | Заказ создан, получен `paymentUrl` |
| [`logs/02-refund.json`](logs/02-refund.json) | `POST /v2/orders/{order_id}/refund` | Возврат принят, операция `REFUND` в статусе `PENDING` |
| [`logs/03-get-order.json`](logs/03-get-order.json) | `GET /v1/orders/{order_id}` | Заказ `REFUNDED`, операции `AUTHORIZE` и `REFUND` в статусе `SUCCESS` |

Отдельный прогон «создание заказа → оплата Сплитом» без возврата, выполнен 11 октября 2026 года:

| Файл | Запрос | Результат |
| --- | --- | --- |
| [`logs/04-get-order-captured.json`](logs/04-get-order-captured.json) | `GET /v1/orders/{order_id}` | Заказ `CAPTURED`, операция `AUTHORIZE` в статусе `SUCCESS` |

Частичный возврат по заказу со скидкой и доставкой, выполнен 12 октября 2026 года:

| Файл | Запрос | Результат |
| --- | --- | --- |
| [`logs/05-partial-refund.json`](logs/05-partial-refund.json) | `POST /v1/orders`, `POST /v2/orders/{order_id}/refund`, `GET /v1/orders/{order_id}` | Возврат трёх позиций из четырёх через `refundCart`, заказ `PARTIALLY_REFUNDED` |

## Логи ошибок

Ошибки, вызванные в Sandbox намеренно 11 октября 2026 года. Разбор каждой — в [справочнике кодов ошибок](../docs/reference/error-codes.md). Файлы с несколькими запросами содержат массив `steps`. В файлах 08 и 09 ответы скопированы вручную, `X-Request-Id` не сохранены: это указано в поле `note`.

| Файл | Запрос | Результат |
| --- | --- | --- |
| [`errors/01-authentication-error.json`](logs/errors/01-authentication-error.json) | `POST /v1/orders` | `401 AUTHENTICATION_ERROR`: в `Authorization` нет пробела после `Api-Key` |
| [`errors/02-cart-item-price-mismatch.json`](logs/errors/02-cart-item-price-mismatch.json) | `POST /v1/orders` | `CART_ITEM_PRICE_MISMATCH`: `total` посчитан по цене до скидки |
| [`errors/03-cart-item-price-mismatch-three-decimals.json`](logs/errors/03-cart-item-price-mismatch-three-decimals.json) | `POST /v1/orders` | `CART_ITEM_PRICE_MISMATCH` вместо `ORDER_CART_DATA_ERROR`: цена с тремя знаками не сходится с `total` |
| [`errors/04-order-cart-data-error.json`](logs/errors/04-order-cart-data-error.json) | `POST /v1/orders` | `ORDER_CART_DATA_ERROR`: 100,00 / 3 даёт цену с бесконечной дробью |
| [`errors/05-refund-amount-expectation-failed.json`](logs/errors/05-refund-amount-expectation-failed.json) | `POST /v2/orders/{order_id}/refund` | `REFUND_AMOUNT_EXPECTATION_FAILED`: сумма возврата посчитана без скидки |
| [`errors/06-refund-only-one-cart.json`](logs/errors/06-refund-only-one-cart.json) | `POST /v2/orders/{order_id}/refund` | `REFUND_ONLY_ONE_CART_EXPECTATION_FAILED` |
| [`errors/07-refund-amount-validation-order.json`](logs/errors/07-refund-amount-validation-order.json) | `POST /v2/orders/{order_id}/refund` | Сумма 0, сумма больше заказа, сумма больше остатка без корзины — во всех случаях `REFUND_AMOUNT_EXPECTATION_FAILED` |
| [`errors/08-invalid-payment-status.json`](logs/errors/08-invalid-payment-status.json) | `POST /v2/orders/{order_id}/refund` | `INVALID_PAYMENT_STATUS`: заказ уже `REFUNDED` |
| [`errors/09-unknown-item-product-id-already-refunded.json`](logs/errors/09-unknown-item-product-id-already-refunded.json) | `POST /v2/orders/{order_id}/refund` | Повтор с тем же `externalOperationId` — `200`; с новым — `ORDERUPDATE_UNKNOWN_ITEM_PRODUCT_ID`, позиции уже возвращены |
| [`errors/10-repeat-same-external-operation-id.json`](logs/errors/10-repeat-same-external-operation-id.json) | `POST /v2/orders/{order_id}/refund` | Повтор с тем же `externalOperationId` — та же операция, `DUPLICATE_EXTERNAL_OPERATION_ID` не приходит |
| [`errors/11-new-external-operation-id-second-refund.json`](logs/errors/11-new-external-operation-id-second-refund.json) | `POST /v2/orders/{order_id}/refund` | Повтор с новым `externalOperationId` — второй возврат |
| [`errors/12-misspelled-target-cart-ignored.json`](logs/errors/12-misspelled-target-cart-ignored.json) | `POST /v2/orders/{order_id}/refund` | Поле `targerCart` с опечаткой проигнорировано, возврат прошёл по `refundCart` |

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
