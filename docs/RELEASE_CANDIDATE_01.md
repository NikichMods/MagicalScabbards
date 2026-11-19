# Устанавливаемый кандидат 01 — 0.1.0-test.1

## Адресный сеанс STOP/restart/STOP 2026-11-19 — PASS

Тот же установленный кандидат `dddd75b6195376521fb8aab9dedeb1232e5f9005`,
все payload SHA-256 повторно совпали с manifest. Пользователь подтвердил корректный
визуальный результат по короткому сценарию. Игра закрыта, полный журнал сохранён локально;
SHA-256 `e4b8463b95c9e4a191c97d475f2359c1c91e1255684eeb089b079f886f4931a6`.

- Автоматический START 03:03:05.742 → HIDDEN targets=6 03:03:41.710.
- Первый F8: RELEASED stop 03:04:06.214 и CLEANED disabled.
- Второй F8: START 03:04:13.942 → HIDDEN targets=6 03:04:17.125,
  через 3.183 с после START; до этого нового START скрытий после STOP нет.
- Третий F8: RELEASED stop 03:04:21.081 и второй CLEANED disabled.
- До Event loop end 03:07:45.380 новых START/HIDDEN и ошибок мода нет:
  мод остался отключённым ещё более трёх минут до закрытия процесса.
- CLEANUP_PENDING, FAULT, START_FAILED, WRITE_FAILED, PROBE_FAILED, WRITER отсутствуют.

**Вывод:** адресный gate явного stop/restart/stop закрыт, вместе с предыдущим сеансом
подтверждён заявленный игровой сценарий с явной остановкой перед выходом.
Повторять его или матрицу оружия не требуется. Прежний owner-ended при завершении
процесса не переобъявляется успешным и его причина остаётся неизвестной: новый сеанс
доказывает штатный F8 cleanup, но не автоматическую очистку при выходе с активной маской.
Горячая выгрузка Lua также не поддерживается. Пакет и runtime не изменены;
main/Release не продвинуты. Решение о продвижении и границе поддержки выхода без STOP
отделено от подтверждённой приёмки контролируемого F8-пути.

## Игровой сеанс 2026-11-19 — PARTIAL PASS, финальная очистка не подтверждена

Проверен установленный payload исходного коммита `dddd75b6195376521fb8aab9dedeb1232e5f9005`;
все SHA-256 совпали с manifest. Архив неизменён, SHA-256
`ea512b7484850ba78d41089abf707c1af233b780ef001f052b7163dd568fb6e1`.
Игра полностью закрыта, полный журнал сохранён локально вне публичного Git;
SHA-256 журнала `94183721faab5edfd4809698f0e6d896bae428ec4174a2bac10ab14d5222516b`.
Пользователь подтвердил выполнение сценария и корректный визуальный результат.

- Автозапуск: loader через enabled.txt в 02:24:59, START в 02:25:00, без F7 по сценарию пользователя.
- 21 HIDDEN: 18 по шесть целей, три по семь. Многократный RELEASED draw-pre.
  Смены комплектов визуально подтверждены пользователем; три RETIRED и RELEASED owner-end-play
  показывают обработку уходящих компонентов. Тихий журнал не записывает точные slots каждого hide,
  поэтому одни лишь counts не являются доказательством всех конкретных loadout.
- Два безопасных release из-за разрыва наблюдений 329.7/346.1 мс с последующим hide;
  один OBSERVATION bracer-pair-stowed-unconfirmed во время действий и последующий hide.
  Ошибки записи или writer-конфликты в этих эпизодах не зарегистрированы.
- Reload: RELEASED load-map-pre 02:30:25.571 → HIDDEN targets=6 02:30:38.815.
- Первый STOP: RELEASED stop и CLEANED disabled 02:30:42.955.
  До повторного START в 02:30:58.414 скрытий нет; restart → HIDDEN targets=6 02:31:01.597,
  через 3.183 с после START. Это подтверждает обычную остановку и новый отсчёт после включения.
- **Финал не чистый:** 02:31:17.828 ERROR CLEANUP_PENDING owner-ended для
  HildaSpear_Unuse_BP_C.SkeletalMesh; затем 02:31:18.837 Event loop end.
  Второго RELEASED stop/CLEANED нет. Нет START_FAILED, WRITE_FAILED, PROBE_FAILED, WRITER
  или иных FAULT-событий мода. Единственная ошибка — указанный долг очистки.

Код помечает owned row как ending, если EndPlay не прошёл строгий destroyed/retired gate;
owned resolver затем отказывается писать в такой объект. Это объясняет смысл owner-ended,
но **не устанавливает причину финального эпизода**: raw EndPlay reason и факт постановки
последнего F8 в очередь в тихом журнале отсутствуют. Выход с активной маской и недоставленная
перед выходом команда — возможные объяснения, не установленный диагноз.
Нельзя считать исчезновение процесса подтверждением успешного rollback.

Итог: визуальный сценарий, automatic startup, смены, reload и первый stop/restart — PASS
в наблюдавшемся объёме. Полный acceptance остаётся BLOCKED на финальной очистке;
main и Release не продвигаются, исходники/пакет не меняются.
Повторять все комплекты не нужно. Минимальная оставшаяся проверка на том же кандидате:
дождаться hide → F8 и видимого восстановления → F8 и нового hide → F8,
дождаться восстановления и ещё 5 секунд, затем выйти; проверить второй CLEANED до выхода.
Если долг повторится до выхода, локализовать только этот lifecycle/STOP эпизод.

## Исходная подготовка и план приёмки (история)

**2026-11-17 · dev/release-prep-01 · подготовлен для адресной игровой приёмки, не принят в production.**
Исходная точка подготовки: `3800c2092e5add74baf6298b64af37d87695b3b2`.
Пять корневых Lua уже были перенесены из Bracer 03; здесь изменён только `Scripts/main.lua`.
Замороженные research-кандидаты неизменны. Никаких изменений установленной игры в этом этапе нет.

## Решения READY / BLOCKED

| Изменение / свойство | Владелец, последний consumer, область влияния | Сохраняемые инварианты / доказательство | Решение |
| --- | --- | --- | --- |
| Автозапуск и остановка/повторное включение через одну F8 | UE4SS исполняет main.lua; main ставит start/stop в явный EngineTick; start владеет ticket, тремя reflected hooks и loop handle. F8 меняет только этот сеанс. | Ранее проверенные EngineTick, loop/cancel, hooks и release Bracer 03. Новый entry point проверен Lua mock с отложенной очередью, отказами регистрации/отмены, устаревшим callback. Политика и setter неизменны. | READY для dev-кандидата; реальный automatic loader start и toggle требуют acceptance ниже. |
| Сокращение диагностики | Локальный log() в main; consumer — только журнал UE4SS, его возвращаемое значение никто не использует. Все вызовы из main/visibility просмотрены. | Не меняет admission/lease/таймер; ошибки, WRITER, HIDDEN, RELEASED, RETIRED, FOREIGN_CONTROLLED, START и CLEANED остаются. Обычные окна/сканирования убраны; повтор одной категории отказа подавляется. Подробный режим выключен в пакете. | READY; quiet-log и failure-path assertions PASS. |
| Источник/версия и layout пакета | Git blobs точного clean HEAD → stdlib ZIP → UE4SS Mods/MagicalScabbards/Scripts/main.lua; enabled.txt запускает Lua-мод. Consumer — существующий UE4SS loader. | Пять Lua, README, лицензии, пустой enabled.txt, manifest; никаких assets/UE4SS/UEHelpers или test dependencies. Хэши и полный состав проверяет packager. | READY для тестового handoff; loading этого ZIP проверяется в игре. |
| Горячая выгрузка/перезагрузка Lua с живыми масками | В reviewed pinned loader нет доказанной для этого мода game-thread cleanup-последовательности перед Lua unload. | Не подменять её вымышленным on_unload API. | BLOCKED / не поддерживается. Достаточный путь — F8 и полное закрытие игры перед заменой файлов. |
| Принятие в main / публичный Release | Пользовательская приёмка точного candidate + журнал реального процесса. | Исследовательские PASS не переименовываются в production acceptance. | BLOCKED до следующего сеанса. |

Источник loader-контракта: [UE4SSProgram.cpp, pinned 83330635](https://github.com/UE4SS-RE/RE-UE4SS/blob/8333063595fa3c49ad307f3b0f732accbb760d25/UE4SS/src/UE4SSProgram.cpp#L1431): сначала mods.txt, затем enabled.txt независимо от строки с 0; повторный start уже запущенного mod пропускается.
[LuaMod.cpp той же версии](https://github.com/UE4SS-RE/RE-UE4SS/blob/8333063595fa3c49ad307f3b0f732accbb760d25/UE4SS/src/Mod/LuaMod.cpp) исполняет main.lua и предоставляет используемые scheduler/hook API.
Сведения об EngineTick/контексте: [общая Research-база](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/VERIFIED_RUNTIME.md#pinned-script-callback-versus-enginetick-execution--source-only-2026-10-30),
игровой baseline и точные пределы — [RELEASE_READINESS.md](RELEASE_READINESS.md).
Это source-level обоснование пути, не наблюдение запуска нового кандидата в игре.

## Реализация и пределы остановки

- Автозапуск однократно ставит start в EngineTick. При отсутствии нужных API,
  EngineTick или свободной Ctrl+Alt+F8 — START_FAILED и отсутствие hide.
- F8 при включённом моде выполняет прежний release, сбрасывает оборудование/таймер,
  обнуляет ticket, отменяет loop и снимает собственные reflected hooks.
  CLEANED означает отсутствие собственного долга/handle/hooks; не обещает переопределять чужую видимость.
- F8 при выключенном и очищенном моде создаёт новый controller/ticket и новое окно.
  При долге, неизвестной регистрации или неотменённом handle вместо restart выполняется
  попытка cleanup; дублирующего сеанса не создаётся. Старый callback не может писать.
- LoadMap pre отпускает свои маски и сбрасывает snapshot/окно, post снимает loading gate.
  Остановленный мод не включается от reload. Lifecycle callbacks и клавиша остаются
  зарегистрированными до конца процесса; F8 не выгружает сам Lua-мод.
- F8 не является сохранённой настройкой. На следующем запуске enabled.txt снова включает мод.
  Для постоянного отключения при закрытой игре убрать enabled.txt **и** включающую запись mods.txt.
- При вмешательстве штатного или чужого writer прежний controller уступает его запись,
  освобождает остальные собственные маски и не начинает цикл перескрытия. Невосстановимая
  identity/ownership выдаёт CLEANUP_PENDING, а не ложный CLEANED. Полный выход уничтожает
  процесс и игровые объекты; состояние видимости не сохраняется модом на диск.

Не добавлены новые FSM, VFX, skill-name списки, drawPending, EndPlay-зависимость для hide,
непрерывность меню или дополнительные цели. equipment/outgoing/reconcile/visibility — точные
Bracer 03 blobs; браслеты остаются только в snapshot/guards, никогда не в целях setter.

## Идентичность и состав

Имя архива: `MagicalScabbards-0.1.0-test.1.zip`; корень внутри — `MagicalScabbards/`.
Версия задаётся единожды в main.lua; имя ZIP и manifest производятся из неё.
`manifest.json` содержит точный source_commit, source_url, версию и SHA-256 всех девяти
payload-файлов (сам manifest не хэширует себя). Рядом с ZIP генерируются его SHA-256 и копия manifest.
Окончательные source SHA и архивный hash берутся из этого manifest/checksum при handoff;
их невозможно вписать внутрь исходного коммита без циклического изменения его identity.

SHA-256 **байтов пакета из Git blobs (LF)**; CRLF рабочего checkout может отличаться:

| Файл в Scripts/ | SHA-256 |
| --- | --- |
| main.lua | `b3bb7ba7c63a92ed1a4cd581cc97e38d4a937ecf894e211b9cab15a9f4756b1a` |
| equipment.lua | `a2c8dbe09ecbf87e8406523e46907914d01f541b1dce3db2cdf0509e7a2300b4` |
| outgoing.lua | `0d220421503c328f777b5b5400eacf3ee23201633b24d6ab8abe85c8e0706ace` |
| reconcile.lua | `4079f5ebed5e7fb10a5cfe66b1204dc5e4218a8d329d65cc1f9e801a43c4d224` |
| visibility.lua | `fc736daefe0aec88fb2da475a39774a99138ebb98801bbfbd36a585cc82138da` |

Остальное: пустой enabled.txt, LICENSE (стандартная MPL-2.0), LICENSING.md, README.md,
сгенерированный manifest.json. Все исходники поставляются в открытом виде;
proprietary материалы и сторонние зависимости отсутствуют.

## Проверки

Локально Python + Lupa 2.8 `lupa.lua54`, `_VERSION == Lua 5.4`: PASS.
`python tools/test.py` запускает без изменения замороженных файлов:

- State Reconcile policy (1030 assertions) и observer; Boundary outgoing;
- Write 01/02, Universal 01, Bracer 01/02/03 на их собственных исходниках;
- весь Bracer 03 integration suite на текущих корневых модулях: адаптированы только
  точка входа (autostart/F8) и test-only включение подробного logger;
- дополнительные tests/test_runtime.lua: production logger, deferred EngineTick,
  2999/3000, stop/restart, reload в активном и выключенном состоянии, stale callback,
  занятую клавишу/отсутствующий API, частичную регистрацию, неуспешную/бросающую отмену
  и unregister, setter rollback, настоящий долг cleanup, отсутствие спама при BLOCKED.

Существующие integration suites сохраняют registry/outgoing races непосредственно перед
и между записями, UNKNOWN/foreign owner, Bracer/held safety, чужой writer, retirement,
partial rollback и редкий census. Это проверки модели на Lua, не native marshalling.

`python tools/package.py` требует чистый коммит, проверяет четыре неизменённых core blob,
SPDX, лицензию, точный layout, manifest/readback всех байтов и два одинаковых ZIP-прохода.
Используются Git blobs, фиксированные ZIP_STORED метаданные: результат не зависит от CRLF
или zlib. CI `Candidate checks` повторяет Lua/packaging на Windows/Python 3.12 + Lupa 2.8,
checkout явно равен github.sha; доступен artifact с коротким сроком хранения.
Результат конкретного запуска CI — в Actions для source_commit из manifest;
ручной runtime acceptance не заменяется зелёным workflow.

## Следующая игровая приёмка — один сеанс после отдельного разрешения на установку

1. Закрыть игру; сохранить старый лог и откат, сверить manifest и оставить только один
   активный кандидат. Запустить игру штатно, **не нажимать F7**. Загрузить сохранение
   с молотом + посохом: после трёх секунд подтверждённого покоя комплект скрывается.
2. Обычная атака молотом: ножны появляются с начала draw, оружие в руке видно.
   Убрать оружие и дождаться повторного hide.
3. Под скрытой маской через меню выбрать парные клинки + копьё. После возврата дождаться
   нового hide; атаковать клинками, проверить held и повторное скрытие после stow.
4. Через меню выбрать Bracer + меч/щит в удобном порядке. Дождаться hide, применить Bracer:
   браслеты видны, допустим общий release; после действия комплект снова скрывается.
   Одна обычная атака мечом проверяет draw/held и возврат к hide.
5. При активной маске загрузить сохранение/карту. После загрузки мод сам начинает новое
   окно и скрывает подтверждённый комплект. Старые объекты не должны оставаться долгом.
6. Под маской нажать F8: комплект возвращается и остаётся видимым дольше четырёх секунд.
   Нажать F8 ещё раз: после нового окна скрывается. Снова F8 под маской и полностью выйти.

Приёмка: визуально нет исчезновения held/браслетов и остаточной части ножен;
в журнале START, HIDDEN, RELEASED draw-pre/load-map-pre/stop по соответствующим действиям,
два CLEANED disabled; нет START_FAILED, FAULT, WRITE_FAILED, PROBE_FAILED или CLEANUP_PENDING.
Порядок/число RELEASED при сменах может зависеть от штатных writers/retirement;
WRITER/FOREIGN_CONTROLLED разбираются по конкретному эпизоду, не стираются как «нормальный шум».
Указать реально активные CombatHUD/HildaSoftLight/косметические моды — это предел утверждения
совместимости. Bracer-only недостижим в штатном меню и не входит в приёмку.
Повторять исторические A/B, шестисемейный read-only и все модельные сочетания в игре не требуется.
**Видео необязательно**, если всё штатно; при мерцании/задержке/невидимом held полезна
короткая запись с начала проблемного эпизода и сохранённый полный журнал.
