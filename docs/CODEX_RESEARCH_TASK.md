# Codex — следующее исследование MagicalScabbards (research-only)

Это задание **для отдельного запуска пользователем**, не приказ немедленно запускать игру.

Сверь локальный checkout, HEAD, main/remote, staged/unstaged/untracked состояние, DevRules (WORKING_RULES, ENGINEERING_RULES, CODEX_WORKFLOW, GIT_WORKFLOW, RUNTIME_INTEGRATION, RUNTIME_TEST_HARNESS), затем актуальные AGENTS.md, docs/REQUIREMENTS.md, docs/STATUS.md и docs/RESEARCH_PLAN.md. Прими новую семантику **draw/stow вместо combat state** с main; безопасно согласуй свою исследовательскую ветку с main без потери существующих локальных изменений. До запуска не повторяй уже доказанные [static 01](https://github.com/NikichMods/MagicalScabbards/blob/9f360eba1dd8eb33eba5e0b6de075c278a664e10/docs/SCABBARD_STATIC_RESEARCH_01.md) и [runtime 01](https://github.com/NikichMods/MagicalScabbards/blob/3d60cf7ce8725f4fa0efa4b2d589a1ac24c73064/docs/SCABBARD_RUNTIME_RESEARCH_01.md).

**Точная задача:** установить в игре начало штатного вынимания и достоверное завершение убирания оружия. Эти переходы должны быть источником показа/скрытия ножен вне зависимости от GetIsBattleState.

- Изучи реальный semantic owner: анимация/equipment state, native/Blueprint events, и компонентных writers scabbard_a/b, отдельно от состояния боевого getter.
- Проверь фактическую доставку callbacks (прежний ExecuteAction observer дал ноль записей), не выдавая её отсутствие в одном маршруте за отсутствие игровых событий.
- Сохрани границы актуальных pawn/attachment, owner; не скрывай всю составную геометрию *_sheath и не выводи роль _use/_unuse из имени.
- Сначала static evidence и сохранённые журналы; если недостаточно — подготовь узкий bounded read-only observer на локальном pawn с лимитами и cleanup. **Не запускать и не перезапускать игру без разрешения пользователя.**
- Никаких production mutations, записей SetVisibility/SetHiddenInGame, изменений сейвов/игровых файлов, пакетов, релизов и VFX.

Выход: документальный отчёт с baseline/hashes, проверенными draw start и stow complete или чётким evidence gap, выбранной минимальной архитектурой/ограничениями и READY/BLOCKED. Обнови статус текущего этапа; общие подтверждённые сведения продвинь в Asterigos-Research с первичным источником. Commit+push в отдельной исследовательской ветке, не перезаписывая историю.

В конце кратко: repo, branch, SHA, push, что подтверждено, что заблокировано, следующий необходимый шаг.
