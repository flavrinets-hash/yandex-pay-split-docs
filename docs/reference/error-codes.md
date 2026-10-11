# Коды ошибок: что проверить

Справочник для разработчика магазина и инженера поддержки: код ошибки → причина → что проверить в запросе. Ответ с ошибкой содержит поля `status: "fail"`, `reasonCode` и `reason`.

Источники: описания методов [`POST /v1/orders`](https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/order/merchant_v1_orders-post), [`POST /v2/orders/{order_id}/refund`](https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/order/merchant_v2_refund-post), [вебхуков](https://pay.yandex.ru/docs/ru/custom/backend/merchant-api/webhook) и [авторизации](https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/).

## Общие

| HTTP | Код / ситуация | Причина | Что проверить |
| --- | --- | --- | --- |
| 401 | — | Не передан или неверен API-ключ | Заголовок `Authorization: Api-Key <ключ>`: слово `Api-Key` и пробел; в Sandbox `merchantId`, в Production ключ от той же среды из ЛК |
| 409 | `ANOTHER_OPERATION_IN_PROGRESS` | По заказу уже выполняется другая операция | Дождаться завершения предыдущей операции (вебхук или `GET /v1/orders/{order_id}`), затем повторить |
| 429, 5xx | — | Превышен лимит запросов или сбой на стороне сервиса | Повторить запрос с паузой и **тем же** `X-Request-Id` |

## Создание заказа — `POST /v1/orders`

| Код | Причина | Что проверить |
| --- | --- | --- |
| `ORDER_CART_DATA_ERROR` | Цена за единицу (`total / quantity.count`) содержит больше двух знаков после запятой | Разбить позицию на несколько с разными `productId` так, чтобы цена делилась без остатка |

## Возврат — `POST /v2/orders/{order_id}/refund`

| Код | Причина | Что проверить |
| --- | --- | --- |
| `REFUND_AMOUNT_EXPECTATION_FAILED` | `refundAmount` не совпадает с суммой, рассчитанной по `targetCart` / `refundCart` | Цены в корзине со скидкой; в `targetCart` перечислены все оставшиеся позиции, включая доставку |
| `REFUND_ONLY_ONE_CART_EXPECTATION_FAILED` | Переданы одновременно `targetCart` и `refundCart` | Оставить одно из полей |
| `REFUND_AMOUNT_TOO_LARGE` | Сумма больше доступного остатка для возврата | Не было ли уже возвратов по заказу (`GET /v1/orders/{order_id}` → `operations`) |
| `REFUND_AMOUNT_TOO_SMALL` | Сумма меньше 1 рубля | `refundAmount` ≥ 1.00 |
| `REFUND_NOT_POSITIVE_AMOUNT` | Сумма не больше нуля | Значение и формат `refundAmount` (строка, например `"1800.00"`) |
| `REFUND_LEAVES_LESS_THAN_MINIMAL_AMOUNT` | После возврата в заказе останется меньше 1 рубля | Сделать полный возврат вместо частичного |
| `ORDER_CART_EMPTY` | Не передана корзина там, где она нужна | Добавить `targetCart` или `refundCart` |
| `ORDER_AMOUNT_MISMATCH` | Сумма заказа не сходится с суммой корзины и доставки | Пересчитать суммы позиций и доставки |
| `ORDERUPDATE_UNKNOWN_ITEM_PRODUCT_ID` | `productId` нет в исходной корзине | Идентификаторы позиций. Те же, что при создании заказа |
| `ORDERUPDATE_DUPLIATE_ITEM_PRODUCT_ID` | В корзине повторяется `productId` | Объединить дубли. Код в API пишется именно так, с опечаткой |
| `ORDERUPDATE_INVALID_ITEM_QUANTITY` | Некорректное `quantityCount` | В `targetCart` — остаток, в `refundCart` — возвращаемое количество; не больше исходного |
| `ORDERUPDATE_INVALID_ITEM_PRICE` | Некорректная `price` | `price` — цена за единицу после операции, строкой с двумя знаками после запятой (например `"4500.00"`) |
| `INVALID_PAYMENT_STATUS` | Текущий статус заказа не допускает возврат | `paymentStatus` должен быть `CAPTURED` или `PARTIALLY_REFUNDED` |
| `PARTIAL_REFUND_NOT_ALLOWED` | Частичный возврат для заказа недоступен | Сделать полный возврат или уточнить условия у Яндекс Пэй |
| `DUPLICATE_EXTERNAL_OPERATION_ID` | Возврат с таким `externalOperationId` уже проведён | Это защита от двойного возврата: проверить статус существующей операции, а не создавать новую |

## Ответы магазина на вебхук

Эти коды возвращает **бэкенд магазина** в ответ на вебхук. Ответ `400` с телом `{"status": "fail", "reasonCode": "...", "reason": "..."}`.

| Код | Когда возвращать |
| --- | --- |
| `UNAUTHORIZED` | Подпись JWT не прошла проверку |
| `TOKEN_EXPIRED` | Истёк срок действия JWT (`exp`) |
| `OTHER` | Другие ошибки проверки, например чужой `merchantId` |

Любой ответ, кроме `200`, Яндекс Пэй считает недоставкой и повторяет вебхук в течение 24 часов.
