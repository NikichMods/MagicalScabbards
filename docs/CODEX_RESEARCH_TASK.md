# Codex — MagicalScabbards: draw/stow семантика и комплекты оружия (research-only)

**Задача для отдельного запуска пользователем.** Рабочая база требований: `main` commit [`54e5dff`](https://github.com/NikichMods/MagicalScabbards/commit/54e5dff8c62415309785daf4df37e2eed71e29ed). Верность новой концепции критична: **скрыть весь убранный комплект — ножны вместе с вложенным оружием; не скрывать оружие в руках.** Боевое состояние не участвует.

## 1. Вход и восстановление

- Проверь реальный checkout `NikichMods/MagicalScabbards`, HEAD/ветку/remote, staged, unstaged, untracked, remote divergence и возможного параллельного writer; ничего не reset/clean/stash автоматически. Прочитай актуальные `NikichMods/DevRules/WORKING_RULES.md`, `ENGINEERING_RULES.md`, `GIT_WORKFLOW.md`, `CODEX_WORKFLOW.md`, `RUNTIME_INTEGRATION.md` и, если требуется новый observer, `RUNTIME_TEST_HARNESS.md`.
- Прочитай локальный `AGENTS.md`, `docs/REQUIREMENTS.md`, `docs/STATUS.md`, `docs/RESEARCH_PLAN.md` и общий `Asterigos-Research/docs/RESEARCH_INDEX.md` / релевантный `VERIFIED_RUNTIME.md`.
- **Повторно использовать, не переснимать:** [статический отчёт `9f360eb`](https://github.com/NikichMods/MagicalScabbards/blob/9f360eba1dd8eb33eba5e0b6de075c278a664e10/docs/SCABBARD_STATIC_RESEARCH_01.md), [runtime-отчёт `3d60cf7`](https://github.com/NikichMods/MagicalScabbards/blob/3d60cf7ce8725f4fa0efa4b2d589a1ac24c73064/docs/SCABBARD_RUNTIME_RESEARCH_01.md) и [исходник observer](https://github.com/NikichMods/MagicalScabbards/blob/3d60cf7ce8725f4fa0efa4b2d589a1ac24c73064/research/scabbard-runtime-01/observer/Scripts/main.lua). Не запускать заново сравнение 15 No Scabbard ресурсов.
- Работай на отдельной `research/scabbard-draw-stow-02` от согласованной актуальной базы, если она ещё не существует; при наличии незавершённой работы не перезаписывай её. Исследовательские коммиты не вливать в `main` без отдельного решения.

## 2. Точный вопрос

На **одном** представительном семействе оружия — `HildaCudgel_BP_C` и связанные `_Use/_Unuse` — найти наиболее простой **достоверный** способ установить:

1. **Начало вынимания** (drawing start): пора отпустить подавление показа убранного комплекта.
2. **Завершение убирания** (stow complete): можно скрыть убранный комплект целиком, включая находящееся в нём оружие.
3. **Актуальные владельцы визуальных компонентов:** `hilda_BP_C.scabbard_a/b`, `HildaCudgel_BP_C.hilda_cudgel_sheath`, актуальные `_Use/_Unuse`. Отличить убранный комплект от активного оружия в руках по object/owner/attachment/actual state, а не по одному названию класса.
4. Какие штатные Blueprint/native writers могут перезаписать `bVisible` или `bHiddenInGame` на выбранном компоненте, и есть ли очевидный безопасный owner для обратимой маски. Не считать, что один прочитанный snapshot доказывает отсутствие writers.

**Новая концепция:** ножны/убранное оружие скрыты в steady `stowed`, видимы с начала `drawing`, при `drawn` и во время `stowing`. Не использовать `GameGlobal:GetIsBattleState` как управление. Принципиально **не требуется** сохранять видимым оружие, которое уже лежит внутри ножен, когда комплект скрыт.

## 3. Самый дешёвый доказательный путь

**Сначала без запуска игры:** прочитай уже доступный cooked Blueprint bytecode/UHT или сохранённые локальные выборочные экспорты, особенно `hilda_BP.ExecuteAction`, `scabbard_on/off`, `weapon_in_hand/leave_hand`, relevant equipment owners/animation notifies. Проверь существующий observer: он регистрировал `RegisterHook` только после первого Ctrl+Alt+F9, фильтровал четыре строки; факт `actions=0` не доказывает отсутствия событий. Определи, в чём именно не хватило доказательства (delivery, правильная функция, аргумент, actor identity, пропущенная стадия), не объявляя ни одну из причин подтверждённой без evidence.

Если этих источников недостаточно, подготовь **один минимальный bounded read-only UE4SS observer** по `RUNTIME_TEST_HARNESS.md`:
- сначала докажи, что выбранная точка наблюдения вообще вызывается и правильно декодирует аргументы, затем только отфильтровывай нужные переходы;
- логируй только verified local pawn и его актуально принадлежащую экипировку, event sequence + bounded time + значения flag/owner/attachment; никаких глобальных поисков каждый тик и спама;
- сценарий — steady stowed → draw start → fully drawn → stow start → stow complete **без обязательного боя**, при нужде одно короткое повторение; перепривязка после reload только при необходимости для конкретного gate;
- бюджет событий/времени, аварийная остановка, cleanup, идентичность скрипта и лога по hash. Статический unit/stub test observer до использования в игре.

**Не запускать, не закрывать и не перезапускать игру самостоятельно без разрешения пользователя.** Можешь подготовить observer, затем оставить пользователю только понятные действия запуска/сценария. Если доступной сессии нет, сохранить готовый observer с пометкой `NOT_RUNTIME_TESTED`, не объявлять вопрос решённым.

## 4. Границы

Только read-only исследование. **Не вызывать** `SetVisibility`, `SetHiddenInGame`, `SetSkeletalMesh`, не делать gameplay write-test, не изменять костюм/оружие/сохранения, не переустанавливать No Scabbard и не трогать чужие моды. Никаких production-кода, versions, CI/release или VFX. Не публиковать игровые/сторонние ассеты, сырые дампы, приватные локальные пути/логи.

## 5. Результат и остановка

В `docs/SCABBARD_DRAW_STOW_RESEARCH_02.md` зафиксировать: baseline, evidence и точные объекты, подтверждённое начало draw/конец stow (или конкретный пробел), карту `hidden assembly` vs `held weapon`, штатные writers, краткое сравнение кандидатов механизма, READY/BLOCKED с причинами и **один** следующий минимальный шаг. Синхронизируй mod-local `docs/STATUS.md` только с фактическими результатами; общие принятые игровые факты — в `Asterigos-Research` со ссылкой на первичный источник.

**Стоп:** получена одна проверяемая цепочка переходов и ownership, достаточная для решения, можно ли делать **отдельный обратимый write-test** в дальнейшем; либо установлен конкретный blocker. Не расширять автоматически на все виды оружия, не реализовывать мод.

Сделай coherent doc/research commit и push исследовательской ветки, проверь SHA remote. В ответе коротко: repo, branch, commit SHA, push, 3–5 выводов, READY/BLOCKED и единственный следующий шаг.
