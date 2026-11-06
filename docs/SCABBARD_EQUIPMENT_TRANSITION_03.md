# MagicalScabbards — equipment transition 03

**BLOCKED для write-test.** Найден штатный Blueprint-писатель `bVisible` на обоих компонентах cudgel. Живой порядок его вызова, перемещения сокета и начала/конца анимации пока открыт.

## Подтверждённая цепочка

Baseline Steam 12996889, UE4.27, UE4SS 83330635. Предыдущий [полный цикл](https://github.com/NikichMods/MagicalScabbards/blob/6df404c2666fb2a23760efdc43f0ddde1ea2fd0a/docs/SCABBARD_DRAW_STOW_RESEARCH_02.md#результат-повтора-2026-11-06) подтвердил тот же локальный актор на `scabbard_a → cudgel_r_hand → scabbard_a`, основные флаги false/true → true/false → false/true. Убирание прошло без доставленных Begin/End. Этот маршрут больше не является основной гипотезой.

Использованы сохранённый CUE4Parse 1.2.2 экспорт `HildaCudgel_BP` (SHA-256 `ccaed6f1476a9671fe48d8ad1b228c0426d0eead7b82a2b049e79a11d1634002`), Weapon row `cudgel_mod00` и UHT `BaseEquipObject.h` / `EWeaponEquipMode.h`. UHT показывает `ABaseEquipObject::EquipModeChange(EWeaponEquipMode)` как BlueprintImplementableEvent и отдельное свойство `equipMode`. Конкретный override `/Game/MainContent/Act/Item_BP/HildaCudgel_BP.HildaCudgel_BP_C:EquipModeChange` имеет один байтовый enum-параметр `equipMode` и входит в `ExecuteUbergraph_HildaCudgel_BP` по смещению 2683.

| Аргумент | Смещения вызовов `SceneComponent:SetVisibility(NewVisibility, false)` | `SkeletalMesh` / `hilda_cudgel_sheath` |
| --- | --- | --- |
| 0 InHand, 3 Floating | 2517, 2551 | true / false |
| 1 Sheath | 2913, 2947 | false / true |
| 2 Inventory, 4 None | 2590, 2624 | false / false |

Это исправляет утверждение [static 01](https://github.com/NikichMods/MagicalScabbards/blob/9f360eba1dd8eb33eba5e0b6de075c278a664e10/docs/SCABBARD_STATIC_RESEARCH_01.md#проверенная-карта-владельцев) об отсутствии прямого writer: конкретный cudgel Blueprint его содержит. Архивный отчёт сохранён. `ExecuteAction` в этом же Blueprint передаёт сообщения вроде `sheath` и `step0` отдельным ветвям; имя сообщения не равнозначно enum-переходу. В теле `EquipModeChange` нет операции переноса корня. Строка Weapon описывает итоговые узлы, но не связывает наблюдавшееся убирание с конкретным вызовом native attachment. UHT-объявления `GameGlobal:SetWeaponInHand` и `SetWeaponAttachReplaceBySlotName` сами по себе этой связи не доказывают.

## A и B

| Подход | Что даёт | Граница |
| --- | --- | --- |
| A — событие `EquipModeChange` и запись `SetVisibility` | Семантический enum и связь с точным компонентным writer, если hook доставляется | Blueprint callback здесь post. Его нельзя считать началом draw. Нужно сравнить socket и флаги до/после writer и после события. Reflected hook не видит каждый прямой C++ вызов. |
| B — текущий owner, root attachment/socket, режим и флаги | Идентификация устойчивого стыка и повторная проверка перед маской; `Sheath` плюс `scabbard_a` и нужные флаги отличают комплект от held mesh | Снимок показывает уже применённое состояние. Он не доказывает ранний draw или окончание визуальной анимации. Класс, сокет и отдельный флаг сами по себе недостаточны. |

Наиболее узкий кандидат — A для наблюдения commit и B для проверки текущей цели. Штатный `bVisible` у `_sheath` занят доказанным writer, поэтому перезапись этого канала непригодна как независимая маска. `bHiddenInGame` на `_sheath` остаётся отдельным кандидатом лишь при проверке владельцев этого канала и отката; для `scabbard_a/b` на pawn уже известен собственный штатный writer `bHiddenInGame`. Не переносить маску на новый pawn или заменённый компонент, на основной меш и на `_Use/_Unuse` по имени. При неизвестном поколении или фазе write-test недопустим. READY требует живого сигнала до первого визуально значимого движения при draw, границы после штатного stow, проверенного состава цели и обоснованного rollback.

## Один следующий шаг

`equipment-commit-observer-01` — read-only, NOT_RUNTIME_TESTED. Подтверждает доставку конкретного Blueprint post и native pre/post `SetVisibility`, логирует порядок, запрошенное значение, отражённый режим, текущий сокет и оба флага. Перед декодированием пишет DELIVERY для точного объекта. Идентичности проверяются по локальному HUD/pawn, одному принадлежащему ему cudgel и двум его компонентам. Точные class lookups только на ручных снимках, callbacks остальных компонентов отсекаются по адресу. Лимит 24 целевых callbacks, 3 снимка, 120 секунд или Ctrl+Alt+F10; cleanup снимает hooks, сохранённые клавиши инертны.

Запуск только вручную по согласованию. Заранее выбрать и убрать тот же обычный молот. Ctrl+Alt+F9 в stowed, штатно вынуть, Ctrl+Alt+F9 в руках, штатно убрать, Ctrl+Alt+F9 в stowed. Сеанс отвечает, доставляются ли оба seams и с каким сокетом/флагами. Если ни один hook не доставлен или первая наблюдаемая точка уже следует за визуальным началом draw, точный разрыв остаётся открытым; write-test не начинать.

Observer Lua SHA-256 `a87ed4ad0259a07f8c54936ed725bb4bbe4fd819203c2d42dba46ba23334bb2b`. Lua 5.4 со стабами: доставка двух типов callback, порядок pre/post и изменение диагностического снимка, отсечение постороннего компонента, несовместимый enum, остановка и инертность после cleanup. Игровые bindings и доставка ещё не проверены.
