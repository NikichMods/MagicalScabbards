# Codex — MagicalScabbards: сравнить способы скрытия вместо дальнейшего углубления в один

**Research-only. Не запускать игру и не менять её состояние без разрешения.** Каноническая UX-цель — `docs/REQUIREMENTS.md`: немедленно показать ножны при draw; после `EquipModeChange(Sheath)` скрыть спустя 2000 мс только при новом подтверждении текущего stowed; таймер отменяется на новом draw/смене/lifecycle. Battle не участвует.

## Контекст и восстановление

Прочитай актуальные DevRules `WORKING_RULES.md`, `ENGINEERING_RULES.md`, `GIT_WORKFLOW.md`, `CODEX_WORKFLOW.md`, при применимости `RUNTIME_TEST_HARNESS.md`/`RUNTIME_INTEGRATION.md`, затем `AGENTS.md`, `docs/REQUIREMENTS.md`, `docs/STATUS.md`, `docs/RESEARCH_PLAN.md`. Сверь локальный checkout/worktrees, staged/unstaged/untracked, upstream и не затри работу.

Повторно используй [Equipment 03](https://github.com/NikichMods/MagicalScabbards/blob/9d14c1aee0eba54e750b074384147f555af6bad8/docs/SCABBARD_EQUIPMENT_TRANSITION_03.md), [Draw 04](https://github.com/NikichMods/MagicalScabbards/blob/5b2e60e0e571788afdfd76969d2a975dbc25cdeb/docs/SCABBARD_DRAW_BOUNDARIES_04.md), [Visual 05](https://github.com/NikichMods/MagicalScabbards/blob/2b0421075f0b3951ebc9f07d3d7d82121017863f/docs/SCABBARD_VISUAL_BOUNDARIES_05.md), [Delayed gate 06](https://github.com/NikichMods/MagicalScabbards/blob/7a73588daef189c5d20d3724b1044124c6e63515/docs/SCABBARD_DELAYED_HIDE_GATE_06.md). Подтверждено: `EquipModeChange` пишет `bVisible` main/sheath, native `SetVisibility` и `SetHiddenInGame` изменяют разные биты; у точного sheath неизвестна история чужих hidden-writes. Не повторять PE/bytecode и прошлые observers. Аппаратный trace — **кандидат**, не заданная обязанность.

## 1. Обязательный краткий solution-space checkpoint

Сравни по фактическому покрытию, простоте, blast radius, откату и взаимодействию с vanilla writer:

**A: кооперативный `SetVisibility` только на live `HildaCudgel_BP_C.hilda_cudgel_sheath`.** После Sheath+2s и подтверждения steady stowed — `SetVisibility(false,false)`. На раннем draw, если этот компонент маскирован и всё ещё относится к steady Sheath, восстановить vanilla-ожидаемую видимость до первой фазы движения; затем игра сама применит `EquipModeChange(InHand)`. При STOP/reload нельзя слепо ставить true — учитывать текущий режим, реальную identity и другие возможные writers. Этот подход использует **тот же** известный канал и может быть простым, если синхронизирован с переходами; доказательств достаточности пока нет.

**B: отдельный `SetHiddenInGame`** на том же sheath, `true/false` без propagation. Преимущество — не трогает штатный `bVisible`. Unknown native/propagated writes и чужие identical-value requests остаются риском; оцени их **пропорционально ограниченному косметическому тесту**, а не требуй математически доказать отсутствие любых писателей во всех игровых сценариях.

**C: штатные pawn `scabbard_a/b` и `hilda_BP_C.ExecuteAction("scabbard_on/off")`.** Это другие компоненты, с доказанным штатным `bHiddenInGame` writer; они могут потребоваться для **полной** цели, но не заменят `cudgel_sheath` с геометрией оружия. Старые hooks на actions не доставились, поэтому не вызывать action вслепую. Нельзя считать один скрытый sheath полной приёмкой «исчезли все ножны».

Actor-wide hide/No Scabbard asset replacement/material swaps/scale=0/global per-frame repair — кратко исключить из первого теста, если не обнаружится материальная причина.

## 2. Самый дешёвый следующий доказательный шаг

Выбери ведущий кандидат A или B для **одного узкого исследовательского write-test на одном stock cudgel**, только если достаточно подтверждённых owner/consumers, режима, возврата к vanilla-поведению и контроля рисков. Составь минимальный тест с явной STOP/cleanup и visual verification: устойчивый stowed, изменение ровно одного компонента, возврат исходного игрового состояния, отсутствие побочных эффектов на held mesh; отдельно сценарий draw→stow→draw до истечения таймера. Сначала offline/stub-проверка таймера, generation tokens, cancel и повторной проверки identity. Отдельно отметь отличия между **готовностью research write-test** и **production READY**.

Если действующий `AGENTS.md` требует именно независимую маску и мешает рассмотреть A, **не обходи** его молча: зафиксируй, что это техническая предпосылка, которую надо пересмотреть в канонических документах, не продуктовая цель.

Native watchpoint предлагать только если есть конкретный доказанный конфликт или недоступная деталь, которую никак не проверить более узким экспериментом; объяснить, какое решение изменит его результат. Не начинать новый широкомасштабный поиск.

## Результат

Работай в новой или актуальной корректной `research/*` ветке без затрагивания чужих изменений. В `docs/RESEARCH_PLAN.md` зафиксируй **короткое** сравнение A/B/C, выбор и проверяемый следующий шаг; отдельный отчёт добавлять только при реальной необходимости. `docs/STATUS.md` — фактический статус. **Никаких gameplay writes, observer installs, запуска игры, production, VFX, версий и релизов в этом этапе.** Блокер остаётся до явного engineering gate. Commit+push, проверить удалённый SHA. Ответ: выбранный вариант, почему, узкий протокол, READY/BLOCKED для research write-test отдельно от production, branch/commit.
