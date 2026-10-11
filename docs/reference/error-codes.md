# Коды ошибок: что проверить

Справочник для разработчика магазина и инженера поддержки: код ошибки → причина → что проверить в запросе. Ответ с ошибкой содержит поля `status: "fail"`, `reasonCode` и `reason`, часто ещё `details` с расчётом, на котором сервер споткнулся.

Источники: описания методов [`POST /v1/orders`](https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/order/merchant_v1_orders-post), [`POST /v2/orders/{order_id}/refund`](https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/order/merchant_v2_refund-post), [вебхуков](https://pay.yandex.ru/docs/ru/custom/backend/merchant-api/webhook) и [авторизации](https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/).

Колонка «Воспроизведено» показывает, вызвана ли ошибка в Sandbox 11 октября 2026 года. Ссылка ведёт на лог запроса и ответа. «Не проверялось» значит, что строка написана только по документации. Все места, где Sandbox отвечает не так, как написано в документации, собраны в справочнике [Отличия Sandbox от документации](sandbox-vs-docs.md).

## Общие

| HTTP | Код / ситуация | Причина | Что проверить | Воспроизведено |
| --- | --- | --- | --- | --- |
| 401 | `AUTHENTICATION_ERROR` | Не передан, неверен или неправильно записан API-ключ | Заголовок `Authorization: Api-Key <ключ>`: слово `Api-Key` и пробел. Без пробела сервер отвечает `Authorization header is malformed`. В Sandbox ключ — `merchantId`, в Production — ключ от той же среды из личного кабинета | [Да](https://github.com/flavrinets-hash/yandex-pay-split-docs/blob/main/examples/logs/errors/01-authentication-error.json) |
| 409 | `ANOTHER_OPERATION_IN_PROGRESS` | По заказу уже выполняется другая операция | Дождаться завершения предыдущей операции (вебхук или `GET /v1/orders/{order_id}`), затем повторить | Не проверялось: в Sandbox возврат завершается за 2–4 секунды |
| 429, 5xx | — | Превышен лимит запросов или сбой на стороне сервиса | Повторить запрос с паузой и **тем же** `X-Request-Id` | Не проверялось |

## Создание заказа — `POST /v1/orders`

| Код | Причина | Что проверить | Воспроизведено |
| --- | --- | --- | --- |
| `CART_ITEM_PRICE_MISMATCH` | `total` позиции не равен `quantity.count` × `discountedUnitPrice` | `total` считается по цене **со скидкой**. В `details` сервер показывает `cart_item_total`, `cart_item_quantity` и `cart_item_price`. Эта проверка срабатывает раньше проверки на знаки после запятой: цена `3000.013` при `total` = `3000` даёт этот код, а не `ORDER_CART_DATA_ERROR` | [Да](https://github.com/flavrinets-hash/yandex-pay-split-docs/blob/main/examples/logs/errors/02-cart-item-price-mismatch.json), [три знака в цене](https://github.com/flavrinets-hash/yandex-pay-split-docs/blob/main/examples/logs/errors/03-cart-item-price-mismatch-three-decimals.json) |
| `ORDER_CART_DATA_ERROR` | Цена за единицу (`total` / `quantity.count`) содержит больше двух знаков после запятой | Разбить позицию на несколько с разными `productId` так, чтобы цена делилась без остатка. Пример: `total` = `100.00` при `count` = `3` | [Да](https://github.com/flavrinets-hash/yandex-pay-split-docs/blob/main/examples/logs/errors/04-order-cart-data-error.json) |

## Возврат — `POST /v2/orders/{order_id}/refund`

Сервер проверяет запрос возврата в определённом порядке, и он не описан в документации. Если передана корзина, сначала сверяется `refundAmount` с суммой, рассчитанной по корзине. Если корзины нет, Sandbox считает возврат полным и сверяет `refundAmount` с остатком заказа. Поэтому на неверную сумму почти всегда приходит `REFUND_AMOUNT_EXPECTATION_FAILED`, а не более конкретный код ([лог](https://github.com/flavrinets-hash/yandex-pay-split-docs/blob/main/examples/logs/errors/07-refund-amount-validation-order.json)).

| Код | Причина | Что проверить | Воспроизведено |
| --- | --- | --- | --- |
| `REFUND_AMOUNT_EXPECTATION_FAILED` | `refundAmount` не совпадает с суммой, рассчитанной по `targetCart` / `refundCart`, или с остатком заказа, если корзины нет | Сумму, которую ожидает API, сервер показывает в `details.actual_refund_amount`. Частые причины: цена до скидки вместо цены со скидкой; в `targetCart` перечислены не все оставшиеся позиции, включая доставку | [Да](https://github.com/flavrinets-hash/yandex-pay-split-docs/blob/main/examples/logs/errors/05-refund-amount-expectation-failed.json) |
| `REFUND_ONLY_ONE_CART_EXPECTATION_FAILED` | Переданы одновременно `targetCart` и `refundCart` | Оставить одно из полей. Если имя поля написано с опечаткой (`targerCart`), сервер молча его игнорирует и проводит возврат по второй корзине | [Да](https://github.com/flavrinets-hash/yandex-pay-split-docs/blob/main/examples/logs/errors/06-refund-only-one-cart.json), [опечатка в имени поля](https://github.com/flavrinets-hash/yandex-pay-split-docs/blob/main/examples/logs/errors/12-misspelled-target-cart-ignored.json) |
| `REFUND_AMOUNT_TOO_LARGE` | Сумма больше доступного остатка для возврата | Не было ли уже возвратов по заказу (`GET /v1/orders/{order_id}` → `operations`) | Нет: и с корзиной, и без неё сервер отвечает `REFUND_AMOUNT_EXPECTATION_FAILED` ([лог](https://github.com/flavrinets-hash/yandex-pay-split-docs/blob/main/examples/logs/errors/07-refund-amount-validation-order.json)) |
| `REFUND_AMOUNT_TOO_SMALL` | Сумма меньше 1 рубля | `refundAmount` ≥ 1.00 | Нет: `0.00` с корзиной даёт `REFUND_AMOUNT_EXPECTATION_FAILED` ([лог](https://github.com/flavrinets-hash/yandex-pay-split-docs/blob/main/examples/logs/errors/07-refund-amount-validation-order.json)) |
| `REFUND_NOT_POSITIVE_AMOUNT` | Сумма не больше нуля | Значение и формат `refundAmount` (строка, например `"1800.00"`) | Нет, см. строку выше |
| `REFUND_LEAVES_LESS_THAN_MINIMAL_AMOUNT` | После возврата в заказе останется меньше 1 рубля | Сделать полный возврат вместо частичного | Не проверялось |
| `ORDER_CART_EMPTY` | Не передана корзина там, где она нужна | Добавить `targetCart` или `refundCart` | Не проверялось |
| `ORDER_AMOUNT_MISMATCH` | Сумма заказа не сходится с суммой корзины и доставки | Пересчитать суммы позиций и доставки | Не проверялось |
| `ORDERUPDATE_UNKNOWN_ITEM_PRODUCT_ID` | `productId` нет в **текущей** корзине заказа: опечатка или позиция уже полностью возвращена | Сравнить `productId` с `cart.items` в `GET /v1/orders/{order_id}`. В тексте ошибки написано «not present in the original cart», но сервер сверяет с корзиной на момент запроса, а не при создании заказа | [Да](https://github.com/flavrinets-hash/yandex-pay-split-docs/blob/main/examples/logs/errors/09-unknown-item-product-id-already-refunded.json) |
| `ORDERUPDATE_DUPLIATE_ITEM_PRODUCT_ID` | В корзине повторяется `productId` | Объединить дубли. Код в API пишется именно так, с опечаткой | Не проверялось |
| `ORDERUPDATE_INVALID_ITEM_QUANTITY` | Некорректное `quantityCount` | В `targetCart` — остаток, в `refundCart` — возвращаемое количество; не больше исходного | Не проверялось |
| `ORDERUPDATE_INVALID_ITEM_PRICE` | Некорректная `price` | `price` — цена за единицу после операции, строкой с двумя знаками после запятой (например `"4500.00"`) | Не проверялось |
| `INVALID_PAYMENT_STATUS` | Текущий статус заказа не допускает возврат | Текущий и допустимые статусы сервер показывает в `details.actual` и `details.expected`, отдельный `GET` не нужен. По документации допустимы `CAPTURED` и `PARTIALLY_REFUNDED`, Sandbox также перечисляет `AUTHORIZED` | [Да](https://github.com/flavrinets-hash/yandex-pay-split-docs/blob/main/examples/logs/errors/08-invalid-payment-status.json) |
| `PARTIAL_REFUND_NOT_ALLOWED` | Частичный возврат для заказа недоступен | Сделать полный возврат или уточнить условия у Яндекс Пэй | Не проверялось |
| `DUPLICATE_EXTERNAL_OPERATION_ID` | По документации — возврат с таким `externalOperationId` уже проведён | Это защита от двойного возврата: проверить статус существующей операции, а не создавать новую | Нет: Sandbox отвечает `200` и возвращает ту же операцию. Подробнее — в разделе [Отличия Sandbox от документации](sandbox-vs-docs.md) |

## Ответы магазина на вебхук

Эти коды возвращает **бэкенд магазина** в ответ на вебхук. Ответ `400` с телом `{"status": "fail", "reasonCode": "...", "reason": "..."}`.

| Код | Когда возвращать |
| --- | --- |
| `UNAUTHORIZED` | Подпись JWT не прошла проверку |
| `TOKEN_EXPIRED` | Истёк срок действия JWT (`exp`) |
| `OTHER` | Другие ошибки проверки, например чужой `merchantId` |

Любой ответ, кроме `200`, Яндекс Пэй считает недоставкой и повторяет вебхук в течение 24 часов.
