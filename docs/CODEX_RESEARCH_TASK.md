# Codex — MagicalScabbards: early draw + stow visual boundary (research-only)

**Следующий отдельный исследовательский этап после [SCABBARD_EQUIPMENT_TRANSITION_03](https://github.com/NikichMods/MagicalScabbards/blob/9d14c1aee0eba54e750b074384147f555af6bad8/docs/SCABBARD_EQUIPMENT_TRANSITION_03.md).** Это готовое задание для запуска пользователем локального Codex, не разрешение самостоятельно запускать, закрывать или перезапускать игру.

## Продуктовая цель

Скрывать **ножны и убранное в них оружие** при устойчивом fully stowed. **С начала штатного вынимания** снять собственное подавление, чтобы ножны были видны в течение draw; удерживать их видимыми пока оружие в руках и при stowing; **после завершения убирания** опять скрыть весь комплект. Не затрагивать оружие в руках. Не использовать `GetIsBattleState`, костыль по фиксированному таймеру или начало первой атаки как недоказанный синоним draw start.

## Состояние доказательств (не повторять)

- [Static 01](https://github.com/NikichMods/MagicalScabbards/blob/9f360eba1dd8eb33eba5e0b6de075c278a664e10/docs/SCABBARD_STATIC_RESEARCH_01.md), [Runtime 01](https://github.com/NikichMods/MagicalScabbards/blob/3d60cf7ce8725f4fa0efa4b2d589a1ac24c73064/docs/SCABBARD_RUNTIME_RESEARCH_01.md), [Draw/stow 02](https://github.com/NikichMods/MagicalScabbards/blob/6df404c2666fb2a23760efdc43f0ddde1ea2fd0a/docs/SCABBARD_DRAW_STOW_RESEARCH_02.md) — неизменённая историческая доказательная база.
- [Equipment transition 03](https://github.com/NikichMods/MagicalScabbards/blob/9d14c1aee0eba54e750b074384147f555af6bad8/docs/SCABBARD_EQUIPMENT_TRANSITION_03.md): тот же актуальный cudgel проходит `cudgel_r_hand → dual_l_hand (Floating) → scabbard_a (Sheath)`. При входе в InHand или Sheath **socket уже изменён до первого `SetVisibility` pre**. Затем два native `SetVisibility`, затем post `HildaCudgel_BP_C:EquipModeChange`. Аргумент post = новый enum, отражённое поле `equipMode` в callback ещё **старое**. Штатный `bVisible` обоих компонентов точно имеет писателя; `bHiddenInGame` у cudgel на снимках оставался false, но это не доказывает отсутствие writers.
- `EquipModeChange(Sheath)` — подтверждённый **commit видимости**, а НЕ доказанный конец анимации. `EquipModeChange(InHand)` и `SetVisibility` pre НЕ доказаны как начало draw: они уже после переноса сокета.
- `BeginDoSkill/EndDoSkill` не сопровождали stow на проверенном маршруте; повторять тот же observer без новой конкретной гипотезы не нужно.
- Новые общие факты промотированы в [Asterigos-Research](https://github.com/NikichMods/Asterigos-Research/commit/6c1b31578f288a81ffe2ed164bfbbc4def837eeb).

## Восстановление и правила

Сверь фактическое состояние локального checkout, worktrees, веток, HEAD, staged/unstaged/untracked и upstream. Прочитай актуальные `NikichMods/DevRules/WORKING_RULES.md`, `ENGINEERING_RULES.md`, `GIT_WORKFLOW.md`, `CODEX_WORKFLOW.md`, при применимости `RUNTIME_INTEGRATION.md` и `RUNTIME_TEST_HARNESS.md`, потом `AGENTS.md`, `docs/REQUIREMENTS.md`, `docs/STATUS.md` и этот документ. Не затри незавершённую работу. Используй отдельную согласованную исследовательскую ветку (например, `research/scabbard-draw-boundaries-04`) поверх актуального продуктового контракта; не вливай исследовательское в `main` без принятия.

## Два минимальных вопроса

**A. Ранний сигнал draw.** Найти игровой вход/intent/dispatched action, который **предшествует** переносу cudgel на `cudgel_r_hand` и предшествует первому визуально значимому движению его вынимания. В первую очередь адресно проследить сохранённый cooked источник/вызовы `GameGlobal:SetWeaponInHand`, `SetWeaponAttachReplaceBySlotName`, запросы `hilda_cudgel_switch_enter`, возможные штатные owner/animation events и исходную команду игрока. Это **кандидаты**, ни один не считать доказанным лишь по имени/декларации. Сравнить ранний native/event seam против узкого read-only наблюдения стадий. Отдельно выяснить, способен ли сигнал вернуть ножны при извлечении **без атаки**, не привязываясь к battle.

**B. Поздний безопасный stow.** Есть `EquipModeChange(Sheath)` после двух штатных записей и при socket `scabbard_a`. Установить, достаточно ли этого для **визуально завершённого** убирания, или штатная анимация продолжается позже. Проверить на имеющихся timeline/animation data, затем минимальным реальным наблюдением при необходимости. `Floating` НЕ считать окончательным `stowed`; поле `equipMode` внутри post может запаздывать.

**Отдельно, но строго минимально:** построить доказательную стратегию собственного suppress/rollback для подтверждённого *holstered assembly*: `HildaCudgel_BP_C.hilda_cudgel_sheath` (+ соответствующие pawn scabbard_a/b лишь при необходимости). Не писать в `bVisible` поверх доказанного штатного writer без специального обоснования; проверить `bHiddenInGame` как кандидат **только на объекте с понятными writers** и не переносить его логику без проверки на pawn components, где у игры уже есть штатный writer этого канала. Никаких действий со stale `_Use/_Unuse`, active held mesh или новым pawn по старому указателю. Продумать отмену подавления в draw, lifecycle, отключение, rollback только собственных живых записей.

## Доказательный маршрут и бюджет

**Сначала без запуска игры:** повторно использовать сохранённые exports, bytecode, UHT, инструменты Codex и публичные отчёты. Выбрать самый короткий путь, который реально отличает ранний draw от позднего equipment commit. Если достаточно, остановить статический этап без нового observer.

Если остаётся конкретный runtime gap — подготовить **один bounded read-only observer** на одном и том же stock cudgel: события/стадии до InHand + (если требуется) граница после Sheath, верифицированный локальный pawn, точная identity, своевременное read-only чтение socket/visible/hidden, ограниченный объём логирования. Зафиксировать исходник/хэш, доказать доставку до фильтрации, протестировать маршруты и cleanup на Lua stubs. Не повторять старый post-only monitor ради тех же значений.

**Не запускать и не перезапускать игру без явного согласия пользователя.** Для проверки визуального начала/конца использовать ограниченное ручное наблюдение пользователя или другой действительно независимый критерий, а не утверждать видимую границу только по логам или по предположительной длине таймлайна.

## Запрещено

Production/write-test, `SetVisibility`, `SetHiddenInGame`, замена игровых пакетов, модификация сейва, загрузка сторонних ассетов в репозиторий, VFX, релиз/версия/CI. Не расширять на все семейства до доказанного representative path. Не превращать research в вечное построение полного native call graph — остановиться при достаточном семантическом seam или конкретном блокере.

## Выход и stop-condition

В новом `docs/SCABBARD_DRAW_BOUNDARIES_04.md` записать: исходный baseline/evidence и hashes; обоснованный кандидат **до** первого значимого движения при draw; подходит/не подходит `EquipModeChange(Sheath)` как точка hide; ownership/rollback для одного полного убранного комплекта, риски и альтернативы; явное **READY/BLOCKED** для следующего **отдельного** обратимого write-test. Если проверить ранний seam в игре невозможно в этом этапе, честно оставить `NOT_RUNTIME_TESTED` и перечислить только конкретный недостающий шаг. Обновить mod-local status по факту. Новые общие подтверждённые game facts — в `Asterigos-Research` с ссылкой на первичные доказательства.

**Стоп:** доказана одна ранняя draw граница + одна безопасная поздняя stow граница + жизнеспособная обратимая поверхность управления **или** установлен точный блокер с одним следующим шагом. Исследовательские изменения commit+push с проверкой remote SHA. Ответ — коротко: branch, SHA, push, confirmed, unknown, READY/BLOCKED, next action.
