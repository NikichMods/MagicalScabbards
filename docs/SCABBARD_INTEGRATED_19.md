# Интегрированный кандидат с несколькими видами оружия

**scabbard-integrated-02 · READY офлайн для ограниченного write-test · NOT_TESTED в игре · production BLOCKED.** База `742a4b21c356f84c4958f42f0d4fda5cabf1c6fd`. [Исходник main.lua](../research/scabbard-integrated-02/runtime/Scripts/main.lua), SHA-256 `8c5065c13c6c1d7cd8ca582fbc3ba5c58e81e69ffba95c2b438cdaa22925ee22` (UTF-8 LF).

## Источник переходов

У [native consumer](https://github.com/NikichMods/MagicalScabbards/blob/5b2e60e0e571788afdfd76969d2a975dbc25cdeb/docs/SCABBARD_DRAW_BOUNDARIES_04.md#от-команды-к-штатному-writer) общий dispatch, но timeline доходит до него в обход известных reflected обёрток. Lua-доставка через базовый `BaseEquipObject:EquipModeChange` при Blueprint override не подтверждена. Поэтому кандидат подключает точные class-specific post hooks к общим переходам. Контроллер масок, таймер, rollback и retirement переиспользованы из [Integrated 18](SCABBARD_INTEGRATED_18.md).

Адресная проверка cooked Blueprint Steam 12996889 через CUE4Parse 1.2.2 с `ReadScriptData=true` дала следующие точки в `ExecuteUbergraph_*`. Это статическое свидетельство формы событий и штатных writers. Доставку и порядок новых hooks должен подтвердить игровой прогон.

| Класс | Sheath и контроль held |
| --- | --- |
| `HildaStaff_BP_C` | Sheath из switch переходит к 6725/6759, основной меш скрывается, отдельный `hilda_staff_sheath` показывается. |
| `HildaDualMain_BP_C` | Sheath 1797/1831/1865 скрывает `SkeletalMesh` и `hilda_dualblade_mesh`, показывает `hilda_dual_sheath`. |
| `HildaDualOff_BP_C` | Sheath 2528 скрывает отдельный `hilda_dualoff_mesh`. Контроль на expiry, собственного hide-таймера от этой руки нет. |
| `HildaSpear_BP_C`, `HildaShield_BP_C` | Sheath 2784/2818 и 3184/3218 соответственно. Для них пока собираются сигналы без своего hide. |

Общий `BeginDoSkill` pre снимает маски и отменяет таймер. Для посоха и клинков новый адаптер допускает Sheath к записи только после наблюдаемой последовательности `hilda_staff_atk1_idle` или `hilda_dual_atk1_idle` на одном ещё stowed акторе с невидимым held и его последующего InHand post. Сами skill ID уже наблюдались в Integrated 18. При Sheath дополнительно обязательны штатная reflected пара показа ножен, локальный владелец, stock mesh, сокет и скрытый held. После 2000 мс перепроверяются тот же актор, актуальные цели, режимы других известных локальных оружейных акторов и отсутствие skill. Для клинков сверяются оба held-меша основного актора и отдельно спрятанный offhand в режиме Sheath. При несовпадении кандидат остаётся в PASS-THROUGH.

Один каталог по-прежнему распознаёт 15 ресурсов. Write-допуск к экземплярам основан на известных ролях и креплениях, не на виде оружия, которое вызвало Sheath. К прежним ролям добавлен `hilda_dual_sheath` в `HildaDualMain_BP_C/scabbard_b` по статической цепочке и [runtime-привязке Lifetime 17](SCABBARD_EQUIPMENT_LIFETIME_17.md#игровой-сеанс-2026-11-08). Варианты стихий и неподтверждённые маршруты остаются вне экспериментального write-допуска. Гипотеза retirement и ограничения прямых native writers сохраняются.

## Офлайн и следующий игровой прогон

Lua 5.4, `lua stub.lua Scripts/main.lua` из каталога runtime. Прошли сценарии молота, посоха и клинков, смены с активной маской, неподтверждённого draw, быстрого overlap и повторного Sheath, отказа скрытия при видимом offhand, чужих writers, частичного отказа, замены экземпляра, reload и STOP/START. Frozen Integrated 01 повторно прошёл свой stub. Игровой PASS молота переиспользуется как свидетельство предыдущего кандидата.

После отдельного разрешения установить при закрытой игре в `ue4ss/Mods/MagicalScabbardsIntegrated02/Scripts/main.lua`, оставить только его активным среди MagicalScabbards. **Ctrl+Alt+F7** — START, **Ctrl+Alt+F8** — STOP. Сначала обычной атакой вынуть посох из второго слота, дать ему убраться и выждать две секунды. Повторить на парных клинках. Проверить ранний возврат деталей, видимое оружие в руках и быструю повторную атаку до hide. Со скрытым комплектом сменить оружие через меню, проверить отсутствие остатка, затем загрузить существующее сохранение и повторить один новый маршрут. При STOP нужен `CLEANED`. При визуальном дефекте или незакрытой маске завершить игру без сохранения. В журнале для новых маршрутов нужны `DRAW_ROUTE`, `SHEATH_ADAPTER`, `HIDDEN` и `RELEASED`. Молот отдельным прогоном повторять не требуется.
