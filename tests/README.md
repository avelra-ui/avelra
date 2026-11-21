# Tests

Тестовая система Avelra. Реализация пишется в `tests/`; `tests-deprecated/`
содержит старый набор только как baseline и не подключается к CI.

## Структура

```text
tests/
├── catalog/
│   ├── catalog.yaml       единственный перечень кейсов
│   ├── case.schema.json   схема кейса
│   ├── providers/         описания провайдеров
│   ├── runners/           реализации действий
│   └── fixtures/          данные и подготовка
├── component/
├── integration/
├── e2e/
├── acceptance/
└── run_tests.sh
```

## Case

Кейс описывает поведение и требования, но не инфраструктуру.

```yaml
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
steps:
  - run: avelra --version
expected: exit code 0 and one version line
assertions:
  - type: exit_code
    equals: 0
  - type: stdout
    matches: "^avelra [0-9]+\\.[0-9]+\\.[0-9]+$"
```

В кейсе запрещены:

```text
environment, adapter, ci, vm, vds, real-machine
```

## Level

Level — масштаб системы под тестом. Один кейс имеет один level.

```text
component    один модуль в процессе; OS/сеть/процессы/UI подменены
contract     граница компонентов/процессов/форматов
integration  реальные компоненты + OS/пакет/сервис; без UI
e2e          собранное приложение + реальный WebView + desktop
acceptance   released/installed artifact + пользовательский сценарий
```

Выбирается наивысший level, который требует проверяемый SUT. Если нужны
assertions разных уровней, это разные кейсы.

## Target и aspect

```text
target  sdk | runtime | app | installer | supply
aspect  behavior | presentation | diagnostics | security | compatibility
```

`presentation` — aspect приложения, не level.

## Technique

```text
functional  штатный сценарий
boundary    граница диапазона/размера/версии
negative    недопустимый ввод или состояние
regression  воспроизведение ранее сломанного поведения
```

## Condition

```text
normal              без инъекций; required capabilities присутствуют
missing-dependency  зависимость отсутствует; expected — ошибка
no-display          desktop session отсутствует; expected — ошибка
unsupported-os      ОС вне support matrix; expected — отказ
```

Condition меняет setup/expected, но не является средой.

## Platform, requires, provider

```text
platform  linux-x64 | windows-x64 | macos-arm64
requires  cli-binary, app-artifact, desktop-session, browser, webkitgtk-4.1, ...
```

Провайдер предоставляет capabilities:

```yaml
id: local-vm-ubuntu-22.04
platform: linux-x64
capabilities:
  - cli-binary
  - guest-os
  - desktop-session
```

Провайдерами могут быть `gh-runner`, `local-vm`, `vds`, `real-machine`.
CI, ручной запуск и release являются schedulers, а не свойствами кейса.

Нет required capability → `skip` с причиной.

## Assertions

```text
exit_code, stdout, stderr, file_exists, file_absent,
json, http_status, dom_text, dom_visible, window_title, browser_url
```

Case status определяется assertions, а не наличием вывода в логе.

## Result

```json
{
  "case": "cli.version",
  "status": "pass",
  "reason": null,
  "provider": "gh-runner",
  "platform": "linux-x64",
  "assertions": [
    {"type": "exit_code", "status": "pass"},
    {"type": "stdout", "status": "pass"}
  ]
}
```

`skip` всегда имеет причину. `fail` содержит провалившиеся assertions.

## Fixtures

Fixture — версионированные входные данные или подготовка. Fixture не знает
про golden, VM, CI или конкретный provider и применяется к workspace, который
предоставил provider.

Изоляцию, одноразовость и cleanup обеспечивает provider. Для app/e2e
используется prebuilt artifact; `init`/`build` внутри кейса запрещены.
