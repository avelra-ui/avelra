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
