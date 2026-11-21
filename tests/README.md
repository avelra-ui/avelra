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

## Model baseline v0

Поля кейса имеют фиксированную семантику:

```text
platform      linux-x64 | windows-x64 | macos-arm64
executions    явные platform+adapter комбинации
adapter       ci | vm
requires      capabilities, которые должен предоставить adapter
condition     normal | missing-dependency | no-display | unsupported-os
technique     functional | boundary | negative | regression
level         component | contract | integration | e2e | acceptance
target        sdk | runtime | app | installer | supply
aspect        behavior | presentation | diagnostics | security | compatibility
```

`normal` — отсутствие инъекций и наличие required capabilities, а не гарантия
успеха. Нет capability → `skip` с причиной.

Открытые вопросы ведутся в developer-документации приватного репозитория.
