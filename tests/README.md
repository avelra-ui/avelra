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
## Модель кейса

Кейс описывает поведение и требования, но не инфраструктуру. В кейсе нет
`ci`, `vm`, `vds`, `real-machine`, `environment` или `adapter`.

### Level

Уровень — масштаб системы под тестом. Один кейс — один уровень.

```text
component    один модуль в процессе; OS/сеть/процессы/UI подменены
contract     граница компонентов/процессов/форматов; exit code, протокол
integration  реальные компоненты + OS/пакет/сервис; без UI
e2e          собранное приложение + реальный WebView + desktop
acceptance   released/installed artifact + пользовательский сценарий
```

Выбирается наивысший уровень, который требует проверяемый SUT. Если нужны
assertions разных уровней — это разные кейсы.

### Target / aspect

```text
target  sdk | runtime | app | installer | supply
aspect  behavior | presentation | diagnostics | security | compatibility
```

### Technique

```text
functional  штатный сценарий
boundary    граница диапазона/размера/версии
negative    недопустимый ввод или состояние
regression  воспроизведение ранее сломанного поведения
```

### Condition

```text
normal              без инъекций; required capabilities есть
missing-dependency  зависимость отсутствует; expected — ошибка
no-display          desktop session отсутствует; expected — ошибка
unsupported-os      ОС вне support matrix; expected — отказ
```

Condition меняет setup/expected, но не является средой.

### Platform, requires, provider

```text
platform  linux-x64 | windows-x64 | macos-arm64
requires  cli-binary, desktop-session, browser, webkitgtk-4.1, ...
```

Провайдер (`gh-runner`, `local-vm`, `vds`, `real-machine`) — внешняя
конфигурация, которая предоставляет capabilities. CI, ручной запуск и release
являются schedulers, а не свойствами кейса.

Нет required capability → `skip` с причиной.

### Пример

```yaml
id: cli.version
level: contract
target: sdk
aspect: behavior
technique: functional
condition: normal
platforms: [linux-x64, windows-x64]
requires: [cli-binary]
runner: cli.command
```
