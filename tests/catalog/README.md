# Canonical test catalog

Это новый canonical каталог тестовой системы. Migration in progress.

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
