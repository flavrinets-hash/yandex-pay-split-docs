# Яндекс Пэй и Сплит: документация для партнёра-разработчика

[![Deploy Docs](https://img.shields.io/github/actions/workflow/status/flavrinets-hash/yandex-pay-split-docs/docs.yml?branch=main&style=flat-square&logo=github&label=Deploy%20Docs)](https://github.com/flavrinets-hash/yandex-pay-split-docs/actions/workflows/docs.yml)
[![Markdown Lint](https://img.shields.io/badge/Markdown-lint-informational?style=flat-square&logo=markdown)](https://github.com/flavrinets-hash/yandex-pay-split-docs/actions/workflows/docs.yml)
[![MkDocs Material](https://img.shields.io/badge/MkDocs-Material-526CFE?style=flat-square&logo=materialformkdocs&logoColor=white)](https://flavrinets-hash.github.io/yandex-pay-split-docs/)

**Сайт документации:** <https://flavrinets-hash.github.io/yandex-pay-split-docs/>

Кейс технической документации по интеграции платёжного API: интернет-магазин подключает оплату через Яндекс Пэй и Яндекс Сплит, проводит тестовые платежи и возвраты, обрабатывает вебхуки. Документация написана для команды разработки магазина и для инженера поддержки, который разбирает обращения партнёров.

> [!NOTE]
> Это неофициальная документация. Она написана по публичной документации [Яндекс Пэй](https://pay.yandex.ru/docs/ru/) и проверена запросами в тестовой среде (Sandbox). Проект не связан с Яндексом. Ключи и идентификаторы в примерах заменены плейсхолдерами.

## Что внутри

| Документ | Тип | Что показывает |
| --- | --- | --- |
| [Подключение оплаты картой](docs/integration/card-only.md) | Пошаговая схема интеграции | Порядок вызовов API, Web SDK, вебхуки, возвраты |
| [Сквозное тестирование в Sandbox](docs/guides/sandbox-e2e.md) | User Guide для разработчиков | Postman, заголовки, создание заказа, оплата, возврат, логи |
| [Частичный возврат](docs/guides/partial-refund.md) | Руководство + разбор механики | `targetCart` и `refundCart`, расчёт суммы со скидкой, обработка вебхуков |
| [На платёжной форме доступен только Сплит](docs/troubleshooting/split-only-payment-form.md) | Troubleshooting, база знаний | Симптом, причина, чек-лист проверки запроса, решение |
| [Сценарий оплаты через Сплит](docs/diagrams/payment-flow.md) | Sequence-диаграмма (Mermaid) | Платёжная сессия, редирект, вебхук, резервный опрос статуса |
| [Статусы заказа и операций](docs/reference/statuses.md) | Справочник | Жизненный цикл заказа и операций |
| [Коды ошибок](docs/reference/error-codes.md) | Справочник для поддержки | Код ошибки → причина → что проверить |
| [Примеры запросов](examples/) | curl и логи | Запросы и ответы Sandbox |

## Инструменты и подход

- **Docs-as-Code:** Markdown, MkDocs Material, Git.
- **CI:** GitHub Actions — markdownlint, проверка JSON-примеров, сборка `mkdocs build --strict`, деплой на GitHub Pages.
- **API:** Postman, curl, REST, JSON, вебхуки с подписью JWT (ES256).
- **Схемы:** Mermaid.

## Как проверялась документация

Описание методов, параметров и статусов API сверено с публичной документацией Яндекс Пэй. Сценарий «создание заказа → оплата Сплитом → возврат → проверка статуса» выполнен в Sandbox, логи запросов и ответов лежат в [`examples/logs`](examples/logs).

Работа вебхуков (формат, проверка подписи JWT, повторы) описана по документации Яндекс Пэй и в Sandbox не проверялась: собственный Callback URL не настраивался.

## Локальная сборка

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
mkdocs serve
```

## Другие проекты

[Telegram Bot API — OpenAPI-документация](https://github.com/flavrinets-hash/Telegram_OpenAPI)
