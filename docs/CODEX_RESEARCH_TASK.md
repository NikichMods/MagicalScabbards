# Codex — MagicalScabbards: безопасный delayed hide (research-only)

**Новый принятый контракт:** `docs/REQUIREMENTS.md`. С начала draw — **немедленно отпустить собственную маску**, отменить pending hide. После `EquipModeChange(Sheath)` post — **через 2 секунды** попытаться скрыть весь убранный комплект (ножны + оружие внутри), **только** если повторная проверка подтверждает текущий устойчивый stowed, прежнюю identity и отсутствие новых draw/смены экипировки. Новые Sheath events должны инвалидировать предыдущий таймер. Боевой getter не участвует; точный stow-end animation event больше не нужен.

## Факты и запреты повторов

Используй [Draw boundaries 04](https://github.com/NikichMods/MagicalScabbards/blob/5b2e60e0e571788afdfd76969d2a975dbc25cdeb/docs/SCABBARD_DRAW_BOUNDARIES_04.md) и [Visual boundaries 05](https://github.com/NikichMods/MagicalScabbards/blob/2b0421075f0b3951ebc9f07d3d7d82121017863f/docs/SCABBARD_VISUAL_BOUNDARIES_05.md) и общий Asterigos-Research: ранний `BeginDoSkill` pre первого удара cudgel доказан до переноса (только этот маршрут); `EquipModeChange(Sheath)` post наступает **до** завершения видимого движения, но одобренная 2-секундная задержка снимает потребность искать завершение анимации; `bVisible` у cudgel имеет штатного writer, независимость `bHiddenInGame` не доказана. Не повторять готовый анализ native equipment pipeline/animation timestamps.

## Точный следующий research gate

Сверь актуальный checkout/worktrees, staged/unstaged/untracked, remote и локальный `AGENTS.md`; прочитай DevRules `WORKING_RULES.md`, `ENGINEERING_RULES.md`, `GIT_WORKFLOW.md`, `CODEX_WORKFLOW.md` и применимые `RUNTIME_INTEGRATION.md`, `RUNTIME_TEST_HARNESS.md`. Сначала исследуй существующие статические данные и исходники.

**Один вопрос:** каким способом безопасно и обратимо подавлять видимость **только текущего** `HildaCudgel_BP_C.hilda_cudgel_sheath`, не перезаписывая штатный `bVisible` и не затрагивая основной held weapon mesh?

- Проверь возможный отдельный `bHiddenInGame` и возможных других writers/propagation; прежнее `hidden=false` или отсутствие reflected callbacks не доказывает отсутствие чужого писателя.
- Определи минимальные identity/lifecycle guards и стратегию восстановления **только собственной** записи на том же живом компоненте, включая reload/new pawn, смену экипировки и отключение.
- Зафиксируй политику таймера как детерминированный одноразовый state machine, включая отмену/инвалидацию при draw, повторном Sheath, interruption, unknown/lifecycle; исключить запись по stale callback.
- Для первого потенциального теста ограничить scope одним подтверждённым cudgel. Покрытие других способов draw (не только первой атаки) — отдельный заявленный пробел, не выдавать за уже поддерживаемое.
- Проверь `ENGINEERING_RULES.md` per-change READY/BLOCKED: owner, final writer/consumer, blast radius, invariants, acceptance. Если нужное доказательство по каналу недоступно статически, назови **одну** минимальную read-only проверку. Не расширяй разбор на все оружия.

**Только research:** не запускать игру без разрешения; не создавать production-мод, write-test, gameplay writes, VFX/релиз/CI. Не трогать чужие файлы, не публиковать игровые ассеты, сырые приватные логи и пути.

В отдельной research-ветке записать `docs/SCABBARD_DELAYED_HIDE_GATE_06.md`: результат анализа канала, политики отмены/rollback, READY/BLOCKED для одного обратимого cudgel write-test и один следующий шаг. Обновить mod-local STATUS по реальным результатам, общие новые доказанные игровые факты — в Asterigos-Research только при необходимости. Commit/push и проверка remote SHA. Не повторять исследование точного stow-animation end: это отменённый продуктовый блокер.
