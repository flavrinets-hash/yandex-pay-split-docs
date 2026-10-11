# На платёжной форме доступен только Сплит

## Симптом

Магазин ожидает, что покупатель сможет оплатить картой полную сумму заказа, но платёжная форма открывается только с оплатой через Сплит.

## Причина

Способы оплаты на форме задаются в запросе [`POST /v1/orders`](https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/order/merchant_v1_orders-post) двумя параметрами:

| Параметр | За что отвечает | Значение, при котором возникает проблема |
| --- | --- | --- |
| `availablePaymentMethods` | Какие способы оплаты доступны на форме | `["SPLIT"]` — доступен только Сплит |
| `preferredPaymentMethod` | Какой способ выбран на форме по умолчанию | `"SPLIT"` — по умолчанию выбран Сплит |

## Как проверить

Сверьте тело запроса `POST /v1/orders` по чек-листу. Если корзина и суммы в порядке, а проблема только в способах оплаты, причина в параметрах из таблицы выше.

| Проверка | Правило |
| --- | --- |
| Сумма позиции | `total` = `discountedUnitPrice` × `quantity.count` |
| Сумма корзины | `cart.total.amount` = сумма `total` всех позиций |
| Цена за единицу | Не больше двух знаков после запятой |
| Данные для чека | Переданы `productId`, `title`, `total`, `quantity.count`, `receipt.tax`, `fiscalContact` |
| Адреса возврата | Переданы `redirectUrls.onSuccess` и `redirectUrls.onError` |
| Время жизни заказа | `ttl` в диапазоне 120–604 800 секунд |
| **Способы оплаты** | `availablePaymentMethods` содержит `"CARD"` |
| **Способ по умолчанию** | `preferredPaymentMethod` равен `"FULLPAYMENT"` |

## Решение {#solution}

Выберите вариант в зависимости от того, что нужно магазину.

=== "Только оплата картой"

    ```json
    {
      "availablePaymentMethods": ["CARD"],
      "preferredPaymentMethod": "FULLPAYMENT"
    }
    ```

=== "Карта и Сплит на выбор"

    На форме доступны оба способа, по умолчанию выбрана оплата полной суммой.

    ```json
    {
      "availablePaymentMethods": ["CARD", "SPLIT"],
      "preferredPaymentMethod": "FULLPAYMENT"
    }
    ```

Остальные поля запроса менять не нужно.

## Пример запроса с ошибкой

Запрос, при котором на форме доступен только Сплит. Корзина и суммы корректны.

```json
{
  "orderId": "<ORDER_ID>",
  "currencyCode": "RUB",
  "availablePaymentMethods": ["SPLIT"],
  "preferredPaymentMethod": "SPLIT",
  "cart": {
    "items": [
      {
        "productId": "<PRODUCT_ID_1>",
        "title": "<PRODUCT_TITLE_1>",
        "unitPrice": "10000.00",
        "discountedUnitPrice": "10000.00",
        "total": "10000.00",
        "quantity": { "count": "1" },
        "receipt": { "tax": 1 }
      },
      {
        "productId": "<PRODUCT_ID_2>",
        "title": "<PRODUCT_TITLE_2>",
        "unitPrice": "2500.00",
        "discountedUnitPrice": "2500.00",
        "total": "5000.00",
        "quantity": { "count": "2" },
        "receipt": { "tax": 1 }
      }
    ],
    "total": { "amount": "15000.00" }
  },
  "fiscalContact": "<CUSTOMER_EMAIL>",
  "redirectUrls": {
    "onSuccess": "https://example.com/order/success?order_id=<ORDER_ID>",
    "onError": "https://example.com/order/error?order_id=<ORDER_ID>",
    "onAbort": "https://example.com/cart"
  },
  "ttl": 1800
}
```

## Что сообщить партнёру

- Почему на форме только Сплит: в запросе `availablePaymentMethods` = `["SPLIT"]` и `preferredPaymentMethod` = `"SPLIT"`.
- Какие значения передать: один из вариантов из раздела [Решение](#solution).
- Что корзину и суммы менять не нужно.
