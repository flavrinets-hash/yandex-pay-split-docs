# Разбор обращения: ошибка в запросе на создание заказа

Пример разбора обращения партнёра на второй линии поддержки: симптом, проверка запроса по документации, причина, исправление.

## Обращение

> Интегрируем базовую механику оплаты. Хотим, чтобы покупатель платил картой всю сумму сразу (фулпейментом), но на платёжной форме открывается только Сплит. Запрос ниже.

```json
{
  "orderId": "930318",
  "currencyCode": "RUB",
  "availablePaymentMethods": ["SPLIT"],
  "preferredPaymentMethod": "SPLIT",
  "cart": {
    "items": [
      {
        "productId": "126329",
        "title": "Роттердам Velvet Pink",
        "unitPrice": "22990.54",
        "discountedUnitPrice": "22990.54",
        "total": "22990.54",
        "quantity": { "count": "1" },
        "receipt": { "tax": 1 }
      },
      {
        "productId": "126330",
        "title": "Роттердам Velvet Blue",
        "unitPrice": "5500",
        "discountedUnitPrice": "5500",
        "total": "22000",
        "quantity": { "count": "4" },
        "receipt": { "tax": 1 }
      }
    ],
    "total": { "amount": "44990.54" }
  },
  "fiscalContact": "client@divan24.ru",
  "redirectUrls": {
    "onSuccess": "https://divan24.ru/order/success?order_id=930318",
    "onError": "https://divan24.ru/order/error?order_id=930318",
    "onAbort": "https://divan24.ru/cart"
  },
  "ttl": 1800
}
```

## Диагностика

Сверяем запрос со спецификацией [`POST /v1/orders`](https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/order/merchant_v1_orders-post).

| Проверка | Результат |
| --- | --- |
| Суммы позиций: `total` = `discountedUnitPrice` × `count` | ✅ 22 990,54 × 1 = 22 990,54; 5 500 × 4 = 22 000 |
| Сумма корзины: `cart.total.amount` = сумма `total` позиций | ✅ 22 990,54 + 22 000 = 44 990,54 |
| Цена за единицу — не больше двух знаков после запятой | ✅ |
| Данные для чека: `productId`, `title`, `total`, `quantity.count`, `receipt.tax`, `fiscalContact` | ✅ переданы |
| `redirectUrls.onSuccess` и `onError` | ✅ переданы |
| `ttl` в диапазоне 120–604 800 секунд | ✅ 1800 |
| **`availablePaymentMethods`** | ❌ `["SPLIT"]` — на форме доступен только Сплит |
| **`preferredPaymentMethod`** | ❌ `"SPLIT"` — по умолчанию выбран Сплит |

## Причина

В RequestBody допущены две ошибки, из-за которых невозможно провести оплату фулпейментом:

1. В параметре `availablePaymentMethods` указано значение **["SPLIT"]**. При таком значении доступен только Сплит. Для оплаты фулпейментом необходимо указать **["CARD"]** или **["CARD", "SPLIT"]**.
2. В параметре `preferredPaymentMethod` указано значение **"SPLIT"**. Для выбора оплаты фулпейментом по умолчанию необходимо указать **"FULLPAYMENT"**.

## Исправление

Исправленные поля запроса — остальное без изменений:

```json
{
  "availablePaymentMethods": ["CARD"],
  "preferredPaymentMethod": "FULLPAYMENT"
}
```

Если магазин хочет оставить покупателю выбор, передайте `"availablePaymentMethods": ["CARD", "SPLIT"]` и `"preferredPaymentMethod": "FULLPAYMENT"` — на форме будут оба способа, по умолчанию выбрана оплата полной суммой.

## Ответ партнёру

> Здравствуйте! На форме открывается только Сплит, потому что в запросе `availablePaymentMethods` равно `["SPLIT"]`, а `preferredPaymentMethod` — `"SPLIT"`. Чтобы покупатель платил картой всю сумму, передайте `"availablePaymentMethods": ["CARD"]` (или `["CARD", "SPLIT"]`, если нужен выбор) и `"preferredPaymentMethod": "FULLPAYMENT"`. Корзина и суммы в запросе корректны, их менять не нужно. Описание полей — в [документации метода](https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/order/merchant_v1_orders-post).
