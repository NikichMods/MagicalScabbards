# MagicalScabbards — актуальный исследовательский план

**2026-11-09 · Research-only; production gate BLOCKED.** Принятые продуктовые требования — в [REQUIREMENTS.md](REQUIREMENTS.md).

## Что уже установлено — не повторять

- [Static 01](https://github.com/NikichMods/MagicalScabbards/blob/9f360eba1dd8eb33eba5e0b6de075c278a664e10/docs/SCABBARD_STATIC_RESEARCH_01.md): все **15 из 15** замен стороннего No Scabbard — пустые SkeletalMesh; сохранены stock asset paths, исходные LOD/секции, Blueprint SCS, владельцы и штатные writers. Сторонняя замена ресурсов не является обратимым runtime-hide.
- [Runtime 01](https://github.com/NikichMods/MagicalScabbards/blob/3d60cf7ce8725f4fa0efa4b2d589a1ac24c73064/docs/SCABBARD_RUNTIME_RESEARCH_01.md): verified local pawn, owner/attachments, появление новых инстансов после reload; battle getter не описывает equip state. В одном снимке после reload `_Unuse` имел owner/attachment к новому pawn; это **кандидат для проверки**, а не подтверждение его участия в последнем визуальном сеансе.
- [Cooperative-cudgel-01/02](https://github.com/NikichMods/MagicalScabbards/blob/24c581305210260ae8e36ea0c4f172323b5312bc/docs/RESEARCH_PLAN.md): на обычном молоте есть частичный runtime PASS для отложенного hide примерно через 2016 мс, раннего release и ручного STOP; подтверждено, что одного `hilda_cudgel_sheath` визуально недостаточно. Полный динамический draw/stow acceptance не получен.
- [A/B изоляция](https://github.com/NikichMods/MagicalScabbards/blob/9fc109cac79895e1ed0cd5fae0e2d71f79c2e49d/docs/SCABBARD_VISUAL_ISOLATION_AB_09.md): `scabbard_a` даёт длинный диагональный корпус и кольцо, `scabbard_b` — небольшую накладку; `hilda_cudgel_sheath` отвечает за нижний выступ.
- [Совместное скрытие 10](https://github.com/NikichMods/MagicalScabbards/blob/a8a76622888d0257e08e8442ffd80cdd5d93453b/docs/SCABBARD_COMBINED_VISIBILITY_10.md): `hilda_cudgel_sheath + scabbard_a + scabbard_b` одновременно скрываются и вручную восстанавливаются (**PASS в игре**); остаются светящийся медальон и тёмные детали на пояснице. Их owner/назначение ещё неизвестны.

## Следующий игровой gate

[Первый read-only сеанс State Reconcile 01](SCABBARD_STATE_RECONCILE_01.md#игровой-сеанс-2026-11-09) подтвердил политику времени и переходы native hand на всех шести семействах. [Boundary 01](SCABBARD_RECONCILE_BOUNDARY_02.md#игровой-сеанс-boundary-01) сопоставил generic pre с кадрами двух обычных draw молота и показал BLOCKED → CLEAR при смене на клинки.

Два [игровых сеанса Write 02](SCABBARD_RECONCILE_WRITE_02.md#игровой-сеанс-2026-11-10) подтвердили устойчивый hide, обычный draw молота, смену под маской с retirement/release и чистый STOP с активной маской. Следующий gate — [один объединённый сеанс Universal 01](SCABBARD_RECONCILE_UNIVERSAL_01.md#один-игровой-сеанс) для пяти допущенных семейств и штатной видимости браслетов. Принятые результаты Write 02 остаются baseline для владения масками.

## История и повторное использование

- [Визуальный A/B](SCABBARD_VISUAL_ISOLATION_AB_09.md), [состав шести целей](SCABBARD_RESIDUAL_ISOLATION_12.md), [динамика молота](SCABBARD_DYNAMIC_CUDGEL_13.md), [граница EndPlay](SCABBARD_ENDPLAY_RELEASE_16.md) и [жизненный цикл экипировки](SCABBARD_EQUIPMENT_LIFETIME_17.md) сохраняют доказательства своих наборов.
- [Integrated 04](SCABBARD_INTEGRATED_21.md), [05](SCABBARD_INTEGRATED_22.md), [06](SCABBARD_INTEGRATED_23.md), [07–08](SCABBARD_INTEGRATED_24.md) — замороженные результаты прежней модели. Из них переиспользуются наблюдения о native slots, активной руке, stock attachments, ранней доставке pre, writers и rollback. Повторять старый событийный таймер и визуальный A/B в новом сеансе не требуется.
