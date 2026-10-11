# Сценарий частичного возврата заказа в Яндекс Сплит

В интернет-магазине был оформлен и успешно оплачен через «Яндекс Сплит» многопозиционный заказ с применённой скидкой и доставкой. Покупатель обратился в поддержку с запросом на возврат только одного товара из чека. Ниже описан сценарий частичного возврата на стороне бэкенда магазина.

## Пошаговый сценарий на стороне бэкенда магазина

1. Покупатель запрашивает возврат Товара 2 (футболки). Менеджер или система формирует заявку на частичный возврат.
2. Бэкенд магазина запрашивает из своей БД состав исходного заказа. Так как к заказу применялась скидка, для расчёта берётся фактическая цена позиции со скидкой (при создании заказа это `discountedUnitPrice`), а не полная цена до скидки (`unitPrice`). В запросе возврата цена позиции передаётся в поле `price` — это цена единицы товара после операции.
3. Бэкенд формирует запрос к эндпоинту `/v2/orders/{order_id}/refund`, где указывает:
    - **refundAmount** — точную сумму возвращаемой позиции с учётом скидки;
    - **targetCart** (целевой остаток корзины) ИЛИ **refundCart** (список возвращаемых товаров);
    - **externalOperationId** — уникальный ID операции на стороне магазина (токен идемпотентности).
4. Запрос отправляется в Яндекс Пэй API.
5. Яндекс Пэй валидирует параметры и возвращает ответ со статусом операции **PENDING** (возврат принят в обработку).
6. После проведения возврата Яндекс Сплит пересчитывает график платежей покупателя и отправляет асинхронные вебхуки на бэкенд магазина.

## Пример запроса к POST /v2/orders/{order_id}/refund

Данные заказа клиента:

- Товар 1 (Джинсы): 1 шт. Базовая цена 5 000 руб., со скидкой 4 500 руб.
- Товар 2 (Футболка): 1 шт. Базовая цена 2 000 руб., со скидкой 1 800 руб.
- Доставка: 300 руб. (передана в исходной корзине отдельной позицией).
- Итого первоначальный чек: 6 600 руб.

Покупатель возвращает Товар 2 (Футболка). Сумма возврата 1 800.00 руб.

**Вариант А. Через targetCart** (указывается то, что останется у покупателя):

```http
POST https://sandbox.pay.yandex.ru/api/merchant/v2/orders/order_test_refund/refund
Authorization: Api-Key {{merchantId}}
X-Request-Id: {{$guid}}
Content-Type: application/json

{
  "externalOperationId": "{{$guid}}",
  "refundAmount": "1800.00",
  "targetCart": {
    "items": [
      {
        "productId": "item_jeans_01",
        "quantityCount": "1",
        "price": "4500.00"
      },
      {
        "productId": "shipping_delivery",
        "quantityCount": "1",
        "price": "300.00"
      }
    ]
  }
}
```

**Вариант Б. Через refundCart** (указывается то, что возвращается):

```http
POST https://sandbox.pay.yandex.ru/api/merchant/v2/orders/order_test_refund/refund
Authorization: Api-Key {{merchantId}}
X-Request-Id: {{$guid}}
Content-Type: application/json

{
  "externalOperationId": "{{$guid}}",
  "refundAmount": "1800.00",
  "refundCart": {
    "items": [
      {
        "productId": "item_tshirt_02",
        "quantityCount": "1"
      }
    ]
  }
}
```

## Механика заполнения полей refundAmount и targetCart

`targetCart` описывает целевой остаток (что останется у клиента после возврата). `refundCart` описывает возвращаемые позиции (что забираем для возврата). Передавать одновременно и `targetCart`, и `refundCart` запрещено API, вернётся ошибка `REFUND_ONLY_ONE_CART_EXPECTATION_FAILED`.

!!! warning "Частая ошибка: в `targetCart` нельзя передавать возвращаемый товар"
    `targetCart` описывает то, что **останется** у покупателя после возврата, а не то, что вы забираете. Всё, чего нет в `targetCart`, API считает возвращённым.

    В примере возвращается футболка, поэтому в `targetCart` нужно передать джинсы и доставку. Если по привычке передать в `targetCart` футболку, запрос будет означать «у покупателя остаётся только футболка» и API вернёт джинсы и доставку.

    Если вам удобнее перечислять возвращаемые позиции, используйте `refundCart` (вариант Б).

`refundAmount` должен совпадать с суммой, которую API рассчитывает по корзине: 6 600.00 − (4 500.00 + 300.00) = 1 800.00. Если в расчёте взять цену без скидки (2 000 вместо 1 800), суммы не сойдутся, и API вернёт ошибку `REFUND_AMOUNT_EXPECTATION_FAILED`.

## Повторный запрос возврата

Если ответ на запрос возврата не пришёл (таймаут, ошибка `5xx`), повторите запрос с тем же `externalOperationId` и тем же телом. Яндекс Пэй вернёт уже созданную операцию с текущим статусом, второй возврат не создаётся ([лог](https://github.com/flavrinets-hash/yandex-pay-split-docs/blob/main/examples/logs/errors/10-repeat-same-external-operation-id.json)).

!!! warning "Не создавайте новый externalOperationId при повторе"
    Запрос с новым `externalOperationId` — это новый возврат. Если возвращается часть количества позиции, покупатель получит деньги дважды ([лог](https://github.com/flavrinets-hash/yandex-pay-split-docs/blob/main/examples/logs/errors/11-new-external-operation-id-second-refund.json)). Создавайте `externalOperationId` один раз на заявку на возврат и сохраняйте его до отправки запроса.

По документации повтор после запуска возврата должен вернуть ошибку `DUPLICATE_EXTERNAL_OPERATION_ID`, но Sandbox отвечает `200`. Подробнее — в справочнике [Отличия Sandbox от документации](../reference/sandbox-vs-docs.md).

## Проверка в Sandbox

Сценарий выполнен в Sandbox 12 октября 2026 года, запросы и ответы — в [логе частичного возврата](https://github.com/flavrinets-hash/yandex-pay-split-docs/blob/main/examples/logs/05-partial-refund.json).

Заказ на 29 300,00 ₽, оплачен Сплитом:

| Позиция | Количество | Цена | Сумма |
| --- | --- | --- | --- |
| `Item_1` | 1 | 3 000,00 ₽ | 3 000,00 ₽ |
| `Item_2` | 4 | 1 500,00 ₽ | 6 000,00 ₽ |
| `Item_3` | 1 | 20 000,00 ₽ со скидкой (30 000,00 ₽ без скидки) | 20 000,00 ₽ |
| `delivery` — доставка | 1 | 300,00 ₽ | 300,00 ₽ |

Доставка передана отдельной позицией корзины, как требует [описание `POST /v1/orders`](https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/order/merchant_v1_orders-post). Поле `targetShipping` в запросе возврата не передавалось: оно работает только в Yandex Pay Checkout. У позиции доставки нет `unitPrice` и `discountedUnitPrice` — без них Яндекс Пэй считает цену как `total` / `quantity.count`.

Возврат через `refundCart`: `Item_1`, `Item_3` и доставка, `refundAmount` = `23300.00` (3 000,00 + 20 000,00 + 300,00). Сумма `Item_3` взята по цене со скидкой.

Результат:

- операция `REFUND` на 23 300,00 ₽ перешла из `PENDING` в `SUCCESS` за 3 секунды;
- заказ перешёл в статус `PARTIALLY_REFUNDED`, `orderAmount` = `6000.00`;
- в корзине заказа осталась только позиция `Item_2`. Возвращённые позиции, включая доставку, из корзины удалены.

## Жизненный цикл статусов и логика обработки вебхуков

**Цепочка смены статусов:**

`CAPTURED` *(заказ полностью оплачен)* ⇒ отправка `POST /refund` ⇒ операция `REFUND` в статусе `PENDING` *(возврат принят Яндексом в обработку, заказ остаётся `CAPTURED`)* ⇒ операция `REFUND` в статусе `SUCCESS`, заказ — `PARTIALLY_REFUNDED` / `REFUNDED` *(статус заказа после возврата)*

**Логика обработки входящих вебхуков на бэкенде мерчанта:**

После проведения возврата Яндекс Пэй присылает на Callback URL магазина две нотификации.

Пример нотификации об операции (`OPERATION_STATUS_UPDATED`):

```json
{
  "merchantId": "<MERCHANT_ID>",
  "event": "OPERATION_STATUS_UPDATED",
  "eventTime": "<EVENT_TIME>",
  "operation": {
    "operationId": "op_refund420",
    "externalOperationId": "refund-order_test_refund-001",
    "orderId": "order_test_refund",
    "status": "SUCCESS",
    "operationType": "REFUND"
  }
}
```

Пример нотификации о статусе заказа (`ORDER_STATUS_UPDATED`):

```json
{
  "merchantId": "<MERCHANT_ID>",
  "event": "ORDER_STATUS_UPDATED",
  "eventTime": "<EVENT_TIME>",
  "order": {
    "orderId": "order_test_refund",
    "paymentStatus": "PARTIALLY_REFUNDED"
  }
}
```

**Что сделать на бэкенде после возврата:**

1. Если `operation.status == "SUCCESS"`, пометить товар как возвращённый; по уведомлению `ORDER_STATUS_UPDATED` обновить статус заказа на `PARTIALLY_REFUNDED`.
2. Если магазин фискализирует платежи через свою онлайн-кассу, сформировать и отправить кассовый чек возврата прихода.

Проверка подписи вебхука, защита от повторной обработки и формат ответа описаны в разделе [Подключение оплаты картой → Шаг 6](../integration/card-only.md#webhook).
