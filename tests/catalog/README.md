# Canonical test catalog

Это canonical каталог тестовой системы. Component test implementations
перенесены в `tests/catalog/tests/component/`; `tests/deprecated/` удалён.

```text
catalog.yaml          case metadata
ci-inventory.yaml     CI test inventory
profiles/             CI/VM profiles
fixtures/             fixtures will be moved here
validate-cases.py     schema validator
validate-ci-inventory.py
report-parity.py
```

Старые тесты находятся в `tests/deprecated/` и пока остаются рабочим CI
fallback. CI execution через этот каталог ещё не подключён; перенос завершён
только структурно.

## Executable

`tests/run_tests.sh` собирает binaries из `tests/catalog/tests/` и запускает
`run-ci.py --all-inventory`. `AVELRA_BUILD_ONLY=1` оставляет только сборку для
CI, где исполнение идёт отдельным catalog step.
