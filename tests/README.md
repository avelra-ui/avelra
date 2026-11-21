# Tests

Тестовая система Avelra. Реализация пишется в `tests/`; `tests-deprecated/`
содержит старый набор только как baseline и не подключается к CI.

## Структура

```text
tests/
├── catalog/
│   ├── catalog.yaml          единственный перечень кейсов
│   ├── case.schema.json      схема кейса
│   ├── provider.schema.json  схема провайдера
│   ├── run-plan.schema.json  схема запуска
│   ├── providers/            описания провайдеров
│   ├── run-plans/            выбранные case/provider
│   ├── runners/              реализации действий
│   ├── run-case.py           executor
│   └── fixtures/             входные данные
├── component/
├── integration/
├── e2e/
├── acceptance/
└── run_tests.sh
```

Запуск:

```bash
./tests/run_tests.sh
```

## Case

```yaml
schema_version: 1
id: cli.version
title: CLI prints version
level: contract
target: sdk
aspect: behavior
technique: functional
condition: normal
platforms: [linux-x64, windows-x64]
requires: [cli-binary]
runner: cli.command
fixture: null
timeout_s: 30
steps:
  - run: avelra --version
expected: exit code 0 and one version line
assertions:
  - id: exit
    type: exit_code
    equals: 0
  - id: version
    type: stdout
    matches: "^avelra [0-9]+\\.[0-9]+\\.[0-9]+$"
```

В кейсе запрещены:

```text
environment, adapter, ci, vm, vds, real-machine, host
```

## Level

```text
component    один модуль в процессе; OS/сеть/процессы/UI подменены
contract     граница компонентов/процессов/форматов
integration  реальные компоненты + OS/пакет/сервис; без UI
e2e          source-built start-app + реальный WebView + desktop
acceptance   released/installed artifact + пользовательский сценарий
```

Правило выбора:

- `e2e` использует source-built start-app;
- `acceptance` использует released/installed artifact;
- assertions разных уровней — разные кейсы.

## Target и aspect

```text
target  sdk | runtime | start-app | installer | supply
aspect  behavior | presentation | diagnostics | security | compatibility
```

`start-app` — единственное приложение, которое проверяет модель.
`presentation` — aspect start-app, не level.

## Technique

```text
functional  штатный сценарий
boundary    граница диапазона/размера/версии
negative    недопустимый ввод или состояние
regression  воспроизведение ранее сломанного поведения
```

У кейса один основной technique.

## Condition

```text
normal
  setup: без инъекций; required capabilities есть
  expected: штатное поведение

missing-dependency
  setup: зависимость отсутствует
  expected: ошибка; не hang и не success
  requires: dependency-removal

no-display
  setup: desktop session отсутствует
  expected: контролируемая ошибка; не hang
  requires: headless
```

Порядок: provision → condition setup → fixture → runner.
Если provider не умеет condition — `skip`.

## Platform, requires, provider

```text
platform  linux-x64 | windows-x64 | macos-arm64
requires  cli-binary, start-app-artifact, desktop-session, browser,
          webkitgtk-4.1, installer, protocol-endpoint, headless,
          dependency-removal, ...
```

Провайдер:

```yaml
schema_version: 1
id: local-vm-ubuntu-22.04
platforms: [linux-x64]
capabilities:
  - cli-binary
  - desktop-session
  - webkitgtk-4.1
```

Провайдерами могут быть `gh-runner`, `local-vm`, `vds`, `real-machine`.
CI, ручной запуск и release являются schedulers, а не свойствами кейса.
Нет required capability → `skip` с причиной.

## Runner и assertions

Runner выполняет действие и возвращает observation, но **не выставляет
pass/fail**.

```json
{
  "exit_code": 0,
  "stdout": "avelra 0.4.2\n",
  "stderr": "",
  "files": {},
  "http": {},
  "dom": {},
  "window": {},
  "browser": {}
}
```

Assertions проверяет executor:

```text
exit_code
stdout / stderr: equals | contains | matches
file_exists / file_absent
json: path + equals
http_status
dom_text / dom_visible
window_title
browser_url
```

`stdout.equals` — точное UTF-8 сравнение. `stdout.matches` — POSIX ERE по
UTF-8 после удаления одного завершающего `\n`.

## Result

```json
{
  "schema_version": 1,
  "case": "cli.version",
  "status": "pass",
  "reason": null,
  "provider": "gh-runner",
  "platform": "linux-x64",
  "duration_s": 1.2,
  "assertions": [
    {"id": "exit", "type": "exit_code", "status": "pass"},
    {"id": "version", "type": "stdout", "status": "pass"}
  ],
  "artifacts": []
}
```

`skip` всегда имеет причину. `fail` содержит провалившиеся assertions.

## Run plan

```yaml
schema_version: 1
scheduler: ci
runs:
  - case: cli.version
    provider: gh-runner
```

Scheduler выбирает provider по platform, requires и condition. Если подходящих
несколько, run plan указывает конкретный; если нет — `skip`.

## Fixtures

Fixture — входные данные, применяемые к workspace provider'а. Fixture не знает
про golden, VM, CI, VDS или provider.

Provider обеспечивает изоляцию, одноразовость и cleanup. Fixture не выполняет
`init`/`build`; для start-app/e2e используется prebuilt artifact.
