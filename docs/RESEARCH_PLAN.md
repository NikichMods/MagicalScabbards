# MagicalScabbards — актуальный исследовательский план

**2026-11-07 · Research-only; production gate BLOCKED.** Принятые продуктовые требования — в [REQUIREMENTS.md](REQUIREMENTS.md). Эта страница описывает **следующую проверку после игрового PASS combined-visibility-01**, а не первоначальный план ранних наблюдателей.

## Что уже установлено — не повторять

- [Static 01](https://github.com/NikichMods/MagicalScabbards/blob/9f360eba1dd8eb33eba5e0b6de075c278a664e10/docs/SCABBARD_STATIC_RESEARCH_01.md): все **15 из 15** замен стороннего No Scabbard — пустые SkeletalMesh; сохранены stock asset paths, исходные LOD/секции, Blueprint SCS, владельцы и штатные writers. Сторонняя замена ресурсов не является обратимым runtime-hide.
- [Runtime 01](https://github.com/NikichMods/MagicalScabbards/blob/3d60cf7ce8725f4fa0efa4b2d589a1ac24c73064/docs/SCABBARD_RUNTIME_RESEARCH_01.md): verified local pawn, owner/attachments, появление новых инстансов после reload; battle getter не описывает equip state. В одном снимке после reload `_Unuse` имел owner/attachment к новому pawn; это **кандидат для проверки**, а не подтверждение его участия в последнем визуальном сеансе.
- [Cooperative-cudgel-01/02](https://github.com/NikichMods/MagicalScabbards/blob/24c581305210260ae8e36ea0c4f172323b5312bc/docs/RESEARCH_PLAN.md): на обычном молоте есть частичный runtime PASS для отложенного hide примерно через 2016 мс, раннего release и ручного STOP; подтверждено, что одного `hilda_cudgel_sheath` визуально недостаточно. Полный динамический draw/stow acceptance не получен.
- [A/B изоляция](https://github.com/NikichMods/MagicalScabbards/blob/9fc109cac79895e1ed0cd5fae0e2d71f79c2e49d/docs/SCABBARD_VISUAL_ISOLATION_AB_09.md): `scabbard_a` даёт длинный диагональный корпус и кольцо, `scabbard_b` — небольшую накладку; `hilda_cudgel_sheath` отвечает за нижний выступ.
- [Совместное скрытие 10](https://github.com/NikichMods/MagicalScabbards/blob/a8a76622888d0257e08e8442ffd80cdd5d93453b/docs/SCABBARD_COMBINED_VISIBILITY_10.md): `hilda_cudgel_sheath + scabbard_a + scabbard_b` одновременно скрываются и вручную восстанавливаются (**PASS в игре**); остаются светящийся медальон и тёмные детали на пояснице. Их owner/назначение ещё неизвестны.

## Результат адресного офлайн-анализа

[Сопоставление кадров, журнала, attachments и LOD0](SCABBARD_COMBINED_VISIBILITY_10.md#адресная-офлайн-проверка-остатка) завершено. Все три остаточные детали остаются без доказанного владельца. Расширение списка из трёх проверенных целей не обосновано.

Следующий gate — [один read-only снимок по 15 исходным ресурсам No Scabbard](SCABBARD_ASSET_CENSUS_11.md), после отдельного разрешения на установку и запуск. Это проверка актуальных instances, owner и attachment на том же stock cudgel в устойчивом stowed со штатной видимостью. Сначала получить `COMPLETE` и список дополнительных кандидатов или подтвердить их отсутствие в покрытом наборе. При наличии обоснованного кандидата согласовать отдельную визуальную изоляцию. Привязка пикселей и GPU-захват для census не требуются.

## После определения визуального состава

Перейти к узкому объединённому кандидату **по состоянию оружия**, а не по battle getter: безопасный ранний release на всех выбранных маршрутах draw, защита от позднего `Sheath` post, отменяемая одноразовая задержка 2 с, проверка поколения pawn/actor/component и фактического stowed, кооперация со штатными visibility writers, восстановление только собственной записи при STOP/lifecycle. Совместный ручной hide/STOP в неподвижном stowed не подтверждает эти переходы. Сначала deterministic stub tests, затем отдельный разрешённый игровой acceptance; `main` не получает runtime до принятия.

Прочие семейства оружия, совместимость с CombatHUD/HildaSoftLight/косметическими пакетами и локальный магический VFX остаются отдельными последующими этапами. Не вводить CI, VERSION, installable artifact или Release без production-механизма и соответствующих gates. Нумерованные/переданные кандидаты неизменяемы.
