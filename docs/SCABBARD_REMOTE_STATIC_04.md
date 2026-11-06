# MagicalScabbards — дистанционный статический аудит 04

**Дата: 2026-11-06. Режим: research-only, без запуска игры. Вердикт: BLOCKED для production и обратимого write-test.** Исследованы опубликованные доказательства. Самостоятельно восстановить *не опубликованную* upstream-цепочку начала вынимания из имеющегося материала нельзя; новая локальная инспекция необходима только для конкретного фрагмента.

## Область и метод

- Актуальная принятая механика: **убранный комплект целиком (ножны + оружие в них) скрыт в stowed; с начала drawing снимается наше подавление; штатная игра управляет анимацией и оружием в руках; после завершения stowing комплект снова скрыт.** Боевой getter и фиксированные задержки не участвуют.
- Сверены [Static 01](https://github.com/NikichMods/MagicalScabbards/blob/9f360eba1dd8eb33eba5e0b6de075c278a664e10/docs/SCABBARD_STATIC_RESEARCH_01.md), [Draw/stow 02](https://github.com/NikichMods/MagicalScabbards/blob/6df404c2666fb2a23760efdc43f0ddde1ea2fd0a/docs/SCABBARD_DRAW_STOW_RESEARCH_02.md), [Equipment transition 03](https://github.com/NikichMods/MagicalScabbards/blob/9d14c1aee0eba54e750b074384147f555af6bad8/docs/SCABBARD_EQUIPMENT_TRANSITION_03.md), `NikichMods/Asterigos-Research/docs/VERIFIED_RUNTIME.md` (включая коммит `6c1b31578f288a81ffe2ed164bfbbc4def837eeb`), актуальные инструкции DevRules и публичные деревья репозиториев MagicalScabbards/Asterigos-Research/StaffRebalance.
- Поиск точных имён `SetWeaponInHand`, `SetWeaponAttachReplaceBySlotName`, `hilda_cudgel_switch_enter`, `EquipModeChange`, `cudgel_mod00`, `sheath_all` в опубликованных текстах NikichMods не выявил исходного caller graph для **начала** вынимания. Отрицательный результат поиска **не доказывает**, что этого кода/события в игре нет.
- В опубликованных ветках MagicalScabbards есть исследования и исходники Lua-наблюдателей; **нет доступных полных выборочных cooked Blueprint/CUE4Parse экспоротов с upstream callers или native реализацией**. Вложения текущего проекта также не предоставили такие исходные данные. Доступный пользовательский No Scabbard содержит подменяющие пустые меши, а не игровые Blueprint/native реализации. Поэтому новые независимые байтовые/bytecode выводы о upstream caller здесь сделать нельзя.
- Игру, пользовательский ПК и невыложенные локальные CUE4Parse/UHT выгрузки этот аудит **не читал**. Исследовательские отчёты остаются первичными источниками; собственная работа — их статическая сверка и ограничение выбора механизма.

## Установленное и пределы статического вывода

| Кандидат | Что подтверждено | Почему не закрывает задачу |
| --- | --- | --- |
| `Weapon.cudgel_mod00` и `hilda_cudgel_switch_enter` | Статическая таблица связывает switch-enter skill с cudgel, timeline `cudgel_in_hand` содержит `set weapon in hand` на ключе 5 | В уже наблюдённом обычном draw зафиксирован `hilda_cudgel_atk1_idle`, а не универсальный switch-enter. Ключ внутри timeline — **не доказанное начало каждого вынимания**. |
| `sheath_cudgel` / `sheath_all` | Штатная таблица и timeline содержат этапы убирания и команды размещения | В повторном runtime-наблюдении устойчивое stow достигнуто **без** доставленных `BeginDoSkill/EndDoSkill`. Нельзя навязать skill-end как универсальную границу. |
| `GameGlobal:SetWeaponInHand`, `SetWeaponAttachReplaceBySlotName` | Из прежнего статического исследования известно наличие UHT-деклараций | Нет опубликованного caller/implementation evidence, доказывающего, какой из методов вызывается в этом маршруте и перед каким визуальным кадром. Название функции — не контракт. |
| Native `SceneComponent:SetVisibility` pre на cudgel | В live-сеансе оба штатных изменения видимости произошли **после** изменения socket | Уже поздняя точка для требования «показать ножны с начала drawing». Штатный `bVisible` занят writer игры. |
| `HildaCudgel_BP_C:EquipModeChange(InHand)` post | Подтверждена доставка post после socket→двух `SetVisibility` | Также поздно для раннего draw; внутри callback свойство `equipMode` ещё старое, аргумент события — новый. |
| `EquipModeChange(Sheath)` post | Подтверждён commit: socket=`scabbard_a`, main `bVisible=false`, sheath `bVisible=true`; Floating ему предшествует | Это подходящая **поздняя граница штатного состояния**, но её совпадение с *последним визуальным кадром* убирания не наблюдалось. Не объявлять окончание анимации доказанным. |
| Совместное чтение owner/socket/flags | Достоверно отличает устойчивые InHand, Floating, Sheath состояния одного живого cudgel в описанном baseline | Снимок уже совершившегося переноса не сообщает о **начале** вынимания. `_Use/_Unuse` могут оставаться устаревшими, а pawn пересоздаётся после load. |

## Инженерное решение

1. **Не использовать** `EquipModeChange(InHand)`, `SetVisibility` pre, `BeginDoSkill(hilda_cudgel_atk1_idle)` или `GetIsBattleState` в качестве *уже доказанного* раннего сигнала draw.
2. **Сохранить как кандидата** `EquipModeChange(Sheath)` post + проверку *актуального* owner, socket, asset, флагов — для безопасной *последующей* маски. Не путать отражённое `equipMode` в post с новым аргументом.
3. **Отдельная поверхность управления видимостью не установлена**: игра доказанно пишет `bVisible` у cudgel sheath, а pawn `scabbard_a/b` имеют штатного writer `bHiddenInGame`. Нельзя гарантировать независимость общей маски; чтение false в нескольких снимках не подтверждает отсутствие другого writer. Скрывать можно **весь убранный комплект**, но не активный weapon mesh.
4. Не увеличивать scope на все виды оружия, общий event bus, периодические глобальные обходы или VFX до установления минимального representative path.

## Минимальный оставшийся статический шаг — требует локальных cooked данных

**Один доказательный вопрос:** какой реальный upstream owner/call перед первым перемещением `HildaCudgel_BP_C` из `scabbard_a` в `cudgel_r_hand` существует **до видимого начала draw** при обычном вынуть/атака, и как он связан с поздним `EquipModeChange`?

Для локального Codex, **только при запуске пользователем**, без новой игры:

1. Восстановить текущий checkout и актуальные DevRules/AGENTS, использовать **существующие локальные** CUE4Parse/UHT/bytecode-экспорты Steam build 12996889. Ничего не скачивать/дампить целиком без реального пробела.
2. Проследить **узкую** цепь из Weapon/Skill/timeline `cudgel_mod00`, `hilda_cudgel_switch_enter`, `hilda_cudgel_atk1_idle`, `sheath_cudgel` к локальному equipment owner. Проверить именно **callers/dispatch** `SetWeaponInHand`, `SetWeaponAttachReplaceBySlotName` и кода вокруг `EquipModeChange`; native декларация без тела и caller остаётся только кандидатом. Не приписывать гарантированную доставку UE4SS-хуку из существования UFunction.
3. Выдать **текстовое краткое свидетельство**: точный объект/функция/owner, путь вызова, расположение до/после изменения socket, ограничение по обычной атаке и выниманию без атаки, что доступно через UE4SS, проверяемая гипотеза для одной точечной runtime-проверки **только если требуется**.
4. Если в сохранённых данных нет тела native writer/caller — отметить точный пробел и предложить **один** read-only observer непосредственно для этого seam; не продолжать бесконечный полный reverse engineering.
5. **Не публиковать** proprietary game assets, полные декомпиляции и локальные machine paths, не менять файлы игры, runtime-состояние, сохранения, релизы и другие моды.

**Stop:** найден upstream сигнал с доказанным порядком из данных или установлен конкретный недоступный native caller; нет нового runtime observer без необходимости. Владелец дальнейшего точного local-research отчёта — `docs/SCABBARD_DRAW_BOUNDARIES_04.md` (по актуальному заданию), а не этот дистанционный аудит.

## Gate

**BLOCKED** для production write-test: (a) ранний семантический draw до первой видимой фазы не подтверждён; (b) stow commit подтверждён, но последняя визуальная граница не доказана; (c) независимый канал подавления/rollback для всех target компонентов не установлен.

Это **не** новая игра/runtime проверка и **не** новая информация для общего Asterigos-Research; повторной промоции прежних фактов не требуется. Достаточные новые выводы здесь — исключение ложноположительных механизмов и точный предел доступных опубликованных источников.
