# Руководство по тестированию в Sandbox

Руководство описывает методику сквозного (E2E) тестирования оплаты частями через Яндекс Сплит в тестовой среде (Sandbox). Оно написано для команды разработки магазина.

!!! info "Важное примечание по авторизации"
    В Sandbox в качестве API-ключа в заголовке `Authorization: Api-Key <значение>` передаётся идентификатор продавца `merchantId`. В Production в этом заголовке передаётся отдельно выпущенный секретный Merchant API Key.

## Шаг 1. Настройте переменные окружения и заголовки в Postman

Создайте в Postman окружение (Environment) со следующими динамическими переменными:

- `baseUrl`: `https://sandbox.pay.yandex.ru/api/merchant`
- `merchantId`: `<MERCHANT_ID>` — идентификатор вашего тестового магазина (в Sandbox используется в качестве API-ключа).
- `orderId`: любое уникальное имя. Уникальность ID критична для предотвращения коллизий при повторных прогонах. Можно задать через Pre-request script запроса на создание заказа:

    ```javascript
    pm.collectionVariables.set("orderId", pm.variables.replaceIn("{{$guid}}"));
    ```

Обязательные заголовки:

- `Authorization: Api-Key {{merchantId}}`
- `Content-Type: application/json`
- `X-Request-Id: {{$guid}}` — уникальный идентификатор запроса. Используется для сквозного логирования, отладки и обеспечения идемпотентности сетевых повторов.

![Заголовки запроса в Postman](../assets/screenshots/01-postman-headers.png)

## Шаг 2. Создайте заказ для Яндекс Сплита (POST /v1/orders)

Запрос инициирует платёжную сессию. Для активации Сплита в теле запроса передаются параметры `availablePaymentMethods` со значением `["CARD", "SPLIT"]` или только `["SPLIT"]` и `preferredPaymentMethod` = `"SPLIT"`. Состав корзины и названия позиций выбираются под задачи теста.

```json
{
  "orderId": "{{orderId}}",
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
```

![Создание заказа в Postman](../assets/screenshots/02-postman-create-order.png)

## Шаг 3. Оплатите заказ на платёжной форме

Из ответа сервера (`data.paymentUrl`) скопируйте полученную ссылку и откройте её в браузере. Проведите транзакцию с помощью эмуляции Sandbox. Статус заказа перейдёт в `CAPTURED`.

![Успешная оплата Сплитом в Sandbox](../assets/screenshots/03-sandbox-payment-success.png)

## Шаг 4. Проверьте входящий вебхук {#webhook}

После списания первого платежа Яндекс отправляет POST-уведомление `ORDER_STATUS_UPDATED` с `paymentStatus` = `"CAPTURED"` на зарегистрированный Callback URL. Тело уведомления — JWT-токен, подписанный алгоритмом ES256. Бэкенд должен верифицировать подпись токена с помощью публичных ключей Яндекса (JWK) и вернуть HTTP 200 OK.

Пример payload уведомления после проверки подписи:

```json
{
  "merchantId": "<MERCHANT_ID>",
  "event": "ORDER_STATUS_UPDATED",
  "eventTime": "<EVENT_TIME>",
  "order": {
    "orderId": "<ORDER_ID>",
    "paymentStatus": "CAPTURED"
  }
}
```

!!! tip "Если вебхук не приходит"
    Вебхук доставляется только на Callback URL, указанный в настройках магазина в Личном кабинете Яндекс Пэй, и только если этот адрес доступен из интернета. Если Callback URL не указан или вы тестируете на локальной машине (`localhost`), уведомление не придёт, но проверить результат оплаты всё равно можно: запросите статус заказа через `GET /v1/orders/{order_id}` — см. [шаг 6](#status-check).

## Шаг 5. Оформите возврат средств (POST /v2/orders/{order_id}/refund)

Для отмены покупки и расторжения договора Сплита бэкенд отправляет запрос на полный возврат средств. В JSON-теле передайте `externalOperationId` — уникальный идентификатор транзакции на стороне магазина (например, `{{$guid}}`), выполняющий функцию токена идемпотентности для защиты от дублирования вызовов.

```json
{
  "externalOperationId": "{{$guid}}",
  "refundAmount": "30000.00"
}
```

![Возврат в Postman](../assets/screenshots/04-postman-refund.png)

Пример payload вебхука об операции (`OPERATION_STATUS_UPDATED`) по документации Яндекс Пэй:

```json
{
  "merchantId": "<MERCHANT_ID>",
  "event": "OPERATION_STATUS_UPDATED",
  "eventTime": "<EVENT_TIME>",
  "operation": {
    "operationId": "<OPERATION_ID>",
    "externalOperationId": "<EXTERNAL_OPERATION_ID>",
    "orderId": "<ORDER_ID>",
    "status": "SUCCESS",
    "operationType": "REFUND"
  }
}
```

Пример payload вебхука о статусе заказа (`ORDER_STATUS_UPDATED`) по документации Яндекс Пэй:

```json
{
  "merchantId": "<MERCHANT_ID>",
  "event": "ORDER_STATUS_UPDATED",
  "eventTime": "<EVENT_TIME>",
  "order": {
    "orderId": "<ORDER_ID>",
    "paymentStatus": "REFUNDED"
  }
}
```

## Шаг 6. Проверьте статус заказа (GET /v1/orders/{order_id}) {#status-check}

Итоговый статус заказа и операций можно проверить запросом `GET {{baseUrl}}/v1/orders/{{orderId}}`. После полного возврата в ответе: `paymentStatus` заказа — `REFUNDED`, операции `AUTHORIZE` и `REFUND` — в статусе `SUCCESS`.

![Статус заказа после возврата](../assets/screenshots/05-postman-get-order.png)

Полные логи запросов и ответов этого прогона — в [`examples/logs`](https://github.com/flavrinets-hash/yandex-pay-split-docs/tree/main/examples/logs).
