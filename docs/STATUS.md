# MagicalScabbards — текущий статус

**2026-11-08 · Research; production gate: BLOCKED.** Публичный проект и исследовательские ветки существуют; **принятого production runtime, установочной версии, CI и релиза нет**. Документационные результаты исследовательских веток допустимо отражать в `main`, но их экспериментальный Lua не является принятым runtime.

## Цель и принятое поведение

**Скрывать штатные ножны вместе с оружием в них только при устойчивом stowed; показывать немедленно при начале draw** с отменой pending hide. Во время drawn и stowing оставлять комплект видимым. После `EquipModeChange(Sheath)` запустить **одну отменяемую задержку 2 секунды**, затем скрыть только при повторной проверке текущих объектов и устойчивого stowed. **Боевой статус не управляет видимостью.** Не менять оружие в руках, анимации, механику, одежду, HUD или соседние моды. Короткий магический VFX — следующий этап после принятия функциональной механики. Канонические критерии: [REQUIREMENTS.md](REQUIREMENTS.md).

## Доказанные результаты и точные пределы

- [Static 01](https://github.com/NikichMods/MagicalScabbards/blob/9f360eba1dd8eb33eba5e0b6de075c278a664e10/docs/SCABBARD_STATIC_RESEARCH_01.md): сторонний No Scabbard заменяет **15/15** известных оригинальных weapon/scabbard ресурсов пустыми SkeletalMesh, включая `*_sheath`, `*_use/_unuse`, `hilda_scabbard_A/B`. Выявлены SCS/Blueprint attachments и writers; статическая замена не доказывает фактическое отображение конкретной детали в игре.
- [Runtime 01](https://github.com/NikichMods/MagicalScabbards/blob/3d60cf7ce8725f4fa0efa4b2d589a1ac24c73064/docs/SCABBARD_RUNTIME_RESEARCH_01.md): реальные владельцы/attachments, новые экземпляры после reload, несовпадение battle и equip state; в одном снимке после reload `_Unuse` прикреплён к pawn, что требует проверки для остаточной геометрии, но **не доказывает** её принадлежность.
- [Cooperative-cudgel-01/02](https://github.com/NikichMods/MagicalScabbards/blob/24c581305210260ae8e36ea0c4f172323b5312bc/docs/RESEARCH_PLAN.md): на обычном молоте частичный игровой PASS для hide после ~2016 мс, раннего release, отмены pending hide и ручного STOP с собственной маской. Одного `hilda_cudgel_sheath` визуально недостаточно. Обычные InHand-атаки и опасный overlap позднего Sheath post не получили полного игрового acceptance.
- [Visual isolation A/B](https://github.com/NikichMods/MagicalScabbards/blob/9fc109cac79895e1ed0cd5fae0e2d71f79c2e49d/docs/SCABBARD_VISUAL_ISOLATION_AB_09.md): **PASS в игре** для поочерёдного hide/show `hilda_BP_C.scabbard_a/b`. A скрывает длинный диагональный корпус и кольцо, B — маленькую накладку; `hilda_cudgel_sheath` отдельно скрывает нижний выступ.
- [Combined visibility 10](https://github.com/NikichMods/MagicalScabbards/blob/a8a76622888d0257e08e8442ffd80cdd5d93453b/docs/SCABBARD_COMBINED_VISIBILITY_10.md): **PASS в игре** для совместного скрытия `hilda_cudgel_sheath + scabbard_a + scabbard_b` и ручного восстановления B → A → sheath с `CLEANED owned=false`. Убранный held mesh оставался скрыт. На пояснице остались светящийся медальон и тёмные детали; их owner неизвестен. Сеанс **не проверял** поведение маски при draw/stow.

## Открытые блокеры

1. **Визуальный состав:** совместное скрытие шести целей подтверждено для проверенного набора. Покрытие других конфигураций остаётся открытым.
2. **Динамика/владение:** подтверждение раннего draw для поддерживаемых маршрутов, корректная обработка перекрывающихся skill/Sheath, вмешательства штатных writers, двухсекундной отмены и rollback только собственной записи, в том числе при lifecycle/reload. Изолированный ручной PASS не закрывает эти gates.
3. **Поддерживаемый объём:** другие виды оружия, совместимость с CombatHUD/HildaSoftLight/косметическими модами и VFX проверяются после безопасного механизма для базового семейства.

## Текущий следующий шаг

[scabbard-asset-census-01](SCABBARD_ASSET_CENSUS_11.md#игровой-результат-2026-11-07) — **PASS** для read-only снимка обычного молота. Помимо трёх контролей найдены три прикреплённых кандидата: spear unuse, staff sheath и dual unuse. Соответствие остаточной геометрии и production остаются **BLOCKED**.

[scabbard-residual-isolation-01](SCABBARD_RESIDUAL_ISOLATION_12.md#повторный-сеанс--pass-для-поочерёдной-изоляции) — **PASS** для трёх одиночных изоляций при скрытой базе и штатного финального восстановления. Пользователь подтвердил визуальный вклад всех трёх дополнительных компонентов. Совместное скрытие шести проверено в следующем сеансе ниже.

[scabbard-dynamic-cudgel-01](SCABBARD_DYNAMIC_CUDGEL_13.md#игровой-сеанс-2026-11-07--pass-в-подтверждённом-наборе) — **PASS** для одновременного скрытия и восстановления шести целей, раннего draw, обычных атак в руках, задержки после Sheath, пропуска позднего Sheath и ручного STOP. Production **BLOCKED**. Отмена уже поставленного таймера — игровой PASS 2026-11-08. Повторный Sheath подтверждён в стабе.

[scabbard-freeplay-01](SCABBARD_FREEPLAY_14.md) подтвердил в игре доставку уведомления о смене слота, восстановление диагностики после reload и STOP. Для проверенной смены Blueprint post уже поздний для всей старой группы. Автоматическая запись при свободной игре BLOCKED.

[scabbard-universal-01](SCABBARD_UNIVERSAL_15.md) подготовлен для read-only проверки привязок на входе в EndPlay и событийной инвентаризации 15 ресурсов. Принято единое правило PASS-THROUGH / SUPPRESSED для произвольного подмножества каталога. Автоматический write-кандидат ждёт безопасной границы смены экипировки, доказательства роли новых экземпляров и владения каналом подавления.

Метод и стоп-условия: [RESEARCH_PLAN.md](RESEARCH_PLAN.md). Исторические test-кандидаты и исходники остаются в `research/*`; не переписывать их frozen SHA. Общие переносимые открытия по Asterigos — в [Asterigos-Research](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/RESEARCH_INDEX.md).

## Репозиторий

[NikichMods/MagicalScabbards](https://github.com/NikichMods/MagicalScabbards); стабильный контракт — `main`, непроверенный runtime — `research/*` / `dev/*`. Первоначальный bootstrap: [6e8062ca](https://github.com/NikichMods/MagicalScabbards/commit/6e8062ca782f2fa72f058a949e7b1e62fc8a052f).
