# Codex — MagicalScabbards: штатный equipment transition и границы скрытия (research-only)

**Следующий отдельный шаг после [draw/stow 02](https://github.com/NikichMods/MagicalScabbards/blob/6df404c2666fb2a23760efdc43f0ddde1ea2fd0a/docs/SCABBARD_DRAW_STOW_RESEARCH_02.md#результат-повтора-2026-11-06).** Задание для пользовательского запуска локального Codex, не инструкция самостоятельно запускать/перезапускать игру.

## Принятая цель

Убранный комплект **ножны + оружие внутри них** скрыт после полного убирания. С **начала вынимания** мод снимает своё подавление; далее до конца убирания игра управляет штатными мешами и анимациями. Оружие в руках никогда не скрывается нашим модом. Ни combat getter, ни произвольный таймер, ни поздняя стадия удара не считаются доказательством нужного перехода. VFX — позже.

## Исходные доказательства (не повторять)

- Статика: [SCABBARD_STATIC_RESEARCH_01.md](https://github.com/NikichMods/MagicalScabbards/blob/9f360eba1dd8eb33eba5e0b6de075c278a664e10/docs/SCABBARD_STATIC_RESEARCH_01.md) — original meshes и владельцы, штатные Blueprint writers, составные *_sheath.
- Runtime 01: [SCABBARD_RUNTIME_RESEARCH_01.md](https://github.com/NikichMods/MagicalScabbards/blob/3d60cf7ce8725f4fa0efa4b2d589a1ac24c73064/docs/SCABBARD_RUNTIME_RESEARCH_01.md) — компоненты текущего local pawn и жизненный цикл.
- Draw/stow 02: [точный повтор `6df404c`](https://github.com/NikichMods/MagicalScabbards/blob/6df404c2666fb2a23760efdc43f0ddde1ea2fd0a/docs/SCABBARD_DRAW_STOW_RESEARCH_02.md#результат-повтора-2026-11-06). На **одном живом `HildaCudgel_BP_C`** стык `scabbard_a → cudgel_r_hand → scabbard_a`; основные флаги `false/true → true/false → false/true`. `hilda_cudgel_atk1_idle` доставлен через native BeginDoSkill только на маршруте draw; **убирание прошло без BeginDoSkill/EndDoSkill**. Эти два метода **не признаны** источником stow completion.
- Общие подтверждённые сведения: [Asterigos-Research](https://github.com/NikichMods/Asterigos-Research/commit/21b0830846d0d90f3ad3b2d8e4d819420976376d).

## Предпроверки и Git

1. Сначала проверь актуальный checkout, worktree, branch, HEAD, staged/unstaged/untracked и upstream, не теряя незавершённую работу. Прочитай актуальные `NikichMods/DevRules/WORKING_RULES.md`, `ENGINEERING_RULES.md`, `GIT_WORKFLOW.md`, `CODEX_WORKFLOW.md`, по применимости `RUNTIME_INTEGRATION.md` и `RUNTIME_TEST_HARNESS.md`.
2. Затем локальный `AGENTS.md`, `docs/REQUIREMENTS.md`, `docs/STATUS.md` и текущий этот документ с `main`, плюс отчёт `02` из исследовательской ветки. Работай в существующей пригодной research-ветке или создай `research/scabbard-equipment-commit-03` без утраты истории/evidence.
3. Сначала определи самый дешёвый достаточный путь по ENGINEERING_RULES: **не обязан** искать сложный полный call graph, если более простой проверяемый штатный сигнал/состояние уже обеспечивает всю принятую семантику.

## Точное техническое исследование

**Вопрос:** что именно штатно переводит текущий `HildaCudgel_BP_C` из `cudgel_r_hand` обратно на `scabbard_a`, переключая `SkeletalMesh.bVisible` и `hilda_cudgel_sheath.bVisible`, и какой доступный сигнал наиболее надёжно различает:
- **начало drawing** (мод должен немедленно убрать свою маску);
- **stow complete** (теперь можно включить маску всего убранного комплекта).

Сначала **статически** проследи доступные прежние локальные cooked Blueprint bytecode/UHT и weapon/timeline data от актуального equipment owner к операции смены attachment/socket, mesh visibility и завершению штатного stow. Установи подтверждённое имя(имена) точек записи/commit, владельца, аргументы, конкретный consumer и прочность вызова через UE4SS. Не угадывай API из названия `set weapon in hand`, `scabbard_on/off` или материала. Отделяй факт reflected UFunction от гарантии доставки callback.

**Сравни два минимальных варианта:** (A) доступное семантическое событие/commit экипировки; (B) наблюдение проверенного текущего attachment/socket и компонентных флагов без произвольных таймеров. Для B явно оцени, способен ли он дать **начало draw**, а не только позднее перемещение в руку. Не отвергай простое наблюдение лишь потому, что оно не является событием; не выбирай его, если семантика визуальной анимации будет нарушена. Для обоих отдельно — штатные писатели `bVisible/bHiddenInGame`, владение нашей обратимой маской, повторный pawn/load, stale _Use/_Unuse, риск скрыть held weapon и границы применимости.

Если direct/source evidence недостаточно, спроектируй **один узкий read-only runtime observer** на **одном выбранном cudgel**, снимающий реальные переходы в минимальном window, с верификацией owner/attachment и порядком writer/commit. Подтверди вызов целевой точки до фильтрации (учитывая провал предыдущего ExecuteAction observation). Бюджет, stop, cleanup, hash source/log, без спама. Используй существующий observer/проверенный UE4SS паттерн, не создавать общий debugger или per-frame scan всех объектов. При отсутствии разрешённого игрового запуска оставь подготовленный observer в исследовательской ветке как **не проверенный в игре**.

## Ограничения

- **Только read-only.** Не менять `SetVisibility`, `SetHiddenInGame`, не запускать gameplay write-test, не ставить production мод и VFX, не менять сейвы, игровые файлы, No Scabbard и соседние моды.
- **Не запускать/перезапускать игру без разрешения пользователя.** Не повторять BeginDoSkill/EndDoSkill-исследование как основную гипотезу: последний повтор уже показал его недостаточность для stow данного маршрута. Не исследовать все семейства оружия раньше закрытия одного representative path.
- Не публиковать proprietary assets, сырые дампы, приватные локальные пути/логи или секреты.

## Результат и остановка

В `docs/SCABBARD_EQUIPMENT_TRANSITION_03.md` сохранить baseline, source/observer provenance, воспроизводимый путь операции (или точный разрыв), **сравнение A vs B**, минимальный writer/consumer, роль узлов `scabbard_a`/`cudgel_r_hand`, конкретные условия READY/BLOCKED для следующего **обратимого write-test**. Статически доказанное и реально наблюдённое отделить друг от друга. В `docs/STATUS.md` актуализировать только результат; новые переносимые подтверждённые игровые факты по правилам продвинуть в Asterigos-Research.

**Stop condition:** одна доказанная и достаточно узкая дорожка для начала draw + конца stow и безопасный класс целей **либо** конкретный недостающий seam и краткий следующий необходимый шаг. Не переходить автоматически к production-патчу или новой версии.

Commit/push в research-ветку с проверкой remote SHA; ответить кратко: branch, SHA, push, подтверждено, не доказано, READY/BLOCKED и один следующий шаг.
