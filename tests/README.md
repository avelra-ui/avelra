# Tests

Новая тестовая система. Реализация начинается с нуля; `tests-deprecated/` —
только baseline для финальной проверки полноты и удаляется после паритета.

```text
tests/catalog/       каталог кейсов, профили, runners, fixtures
tests/tests/         реализации component/integration/e2e
tests/run_tests.sh   единая точка входа
```

Правила:

- case ID и expected определяются заново;
- assertions живут в кейсе/runner, не в старых smoke-скриптах;
- CI и VM используют один каталог;
- старые имена, inventory и списки тестов не переносятся;
- `tests-deprecated/` не подключается к CI.
## Model baseline v1 (draft)

Кейс описывает поведение и требования, но не инфраструктуру.

```text
id / title
level / target / aspect
technique / condition
platforms
requires
runner
```

В кейсе нет `ci`, `vm`, `vds`, `real-machine`, `adapter` или `environment`.

```text
requires:  cli-binary, desktop-session, browser, webkitgtk-4.1, ...
provider:  gh-runner | local-vm | vds | real-machine
```

Provider — внешняя конфигурация; он предоставляет capabilities. CI, ручной
запуск и release — schedulers, а не свойства теста.

Condition (`normal`, `missing-dependency`, `no-display`, `unsupported-os`)
меняет setup/expected, но не является средой.

Открытые вопросы ведутся в приватной developer-документации.
