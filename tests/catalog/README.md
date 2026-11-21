# Catalog

Единственный перечень тестовых кейсов.

```text
catalog.yaml       cases
case.schema.json   схема кейса
provider.schema.json
run-plan.schema.json
providers/         описания провайдеров
run-plans/         выбранные case/provider
runners/           реализации действий
fixtures/          входные данные
```

`run-case.py` исполняет один кейс: runner собирает observation, executor
проверяет assertions.
