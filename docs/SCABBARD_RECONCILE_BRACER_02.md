# State Reconciliation — Bracer 02

**Исследовательский кандидат · Lua 5.4 PASS · игра NOT_TESTED · production BLOCKED.** База `c5f46c1e220bf6085020d593e5bdf6997b1cbd48`. [Исходник проверки](../research/scabbard-reconcile-bracer-02/Scripts/outgoing.lua)

[Bracer 01](SCABBARD_RECONCILE_BRACER_01.md#игровой-сеанс-2026-11-10) достиг трёхсекундного окна, но получил 22 отказа на видимом локальном `hilda_bracelet` вне selected registry. По принятому контракту штатный wrist-only mesh не является уходящим оружием, которому нужны ножны.

Единственное изменение runtime — ветка outgoing-проверки не считает точный stock asset `hilda_bracelet` угрозой для hide, когда его актор отсутствует в selected registry. Он по-прежнему учитывается при проверке полноты census для выбранных акторов. Native snapshot, stowed Bracer, каталог целей, guards настоящего оружия, lease/rollback, 3000 мс и общий `BeginDoSkill` release совпадают с Bracer 01. Браслет по-прежнему вне целей setter.

Lua 5.4 через Lupa 2.8. Оба порядка Bracer + ShieldSword получают hide в стабе с видимым браслетом вне registry, оба браслета остаются видимыми. Тот же harness со старым outgoing воспроизводит отказ на этом сценарии. Видимый уходящий молот, меч, щит и копьё остаются `BLOCKED`; меч с неясным локальным owner — `UNKNOWN`. Прошли STOP, reload и проверки lease из harness, а также замороженные Bracer 01, Universal 01, Boundary 01 и 1030 assertions политики.

SHA-256 `outgoing.lua` в UTF-8 LF — `0d220421503c328f777b5b5400eacf3ee23201633b24d6ab8abe85c8e0706ace`. Остальные четыре хэша совпадают с [Bracer 01](SCABBARD_RECONCILE_BRACER_01.md#проверки).

## Короткий игровой gate

После отдельного разрешения на установку включить **Ctrl+Alt+F7** на штатном Bracer + ShieldSword. В покое подождать 4–5 секунд, проверить исчезновение ножен при видимых браслетах, затем вынуть меч обычной атакой. Ножны должны вернуться с начала draw, меч остаться видимым. После stowed дождаться повторного скрытия и нажать **Ctrl+Alt+F8** под маской. Нужен `CLEANED stop` без долга и видимое восстановление комплекта. Если hide снова не состоится, исследовать только конкретный новый отказ из журнала.
