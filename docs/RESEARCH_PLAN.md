# MagicalScabbards — актуальный исследовательский план

**2026-11-08 · Research-only; production gate BLOCKED.** Принятые продуктовые требования — в [REQUIREMENTS.md](REQUIREMENTS.md).

## Что уже установлено — не повторять

- [Static 01](https://github.com/NikichMods/MagicalScabbards/blob/9f360eba1dd8eb33eba5e0b6de075c278a664e10/docs/SCABBARD_STATIC_RESEARCH_01.md): все **15 из 15** замен стороннего No Scabbard — пустые SkeletalMesh; сохранены stock asset paths, исходные LOD/секции, Blueprint SCS, владельцы и штатные writers. Сторонняя замена ресурсов не является обратимым runtime-hide.
- [Runtime 01](https://github.com/NikichMods/MagicalScabbards/blob/3d60cf7ce8725f4fa0efa4b2d589a1ac24c73064/docs/SCABBARD_RUNTIME_RESEARCH_01.md): verified local pawn, owner/attachments, появление новых инстансов после reload; battle getter не описывает equip state. В одном снимке после reload `_Unuse` имел owner/attachment к новому pawn; это **кандидат для проверки**, а не подтверждение его участия в последнем визуальном сеансе.
- [Cooperative-cudgel-01/02](https://github.com/NikichMods/MagicalScabbards/blob/24c581305210260ae8e36ea0c4f172323b5312bc/docs/RESEARCH_PLAN.md): на обычном молоте есть частичный runtime PASS для отложенного hide примерно через 2016 мс, раннего release и ручного STOP; подтверждено, что одного `hilda_cudgel_sheath` визуально недостаточно. Полный динамический draw/stow acceptance не получен.
- [A/B изоляция](https://github.com/NikichMods/MagicalScabbards/blob/9fc109cac79895e1ed0cd5fae0e2d71f79c2e49d/docs/SCABBARD_VISUAL_ISOLATION_AB_09.md): `scabbard_a` даёт длинный диагональный корпус и кольцо, `scabbard_b` — небольшую накладку; `hilda_cudgel_sheath` отвечает за нижний выступ.
- [Совместное скрытие 10](https://github.com/NikichMods/MagicalScabbards/blob/a8a76622888d0257e08e8442ffd80cdd5d93453b/docs/SCABBARD_COMBINED_VISIBILITY_10.md): `hilda_cudgel_sheath + scabbard_a + scabbard_b` одновременно скрываются и вручную восстанавливаются (**PASS в игре**); остаются светящийся медальон и тёмные детали на пояснице. Их owner/назначение ещё неизвестны.

## Результат адресного офлайн-анализа

[Сопоставление кадров, журнала, attachments и LOD0](SCABBARD_COMBINED_VISIBILITY_10.md#адресная-офлайн-проверка-остатка) завершено. Все три остаточные детали остаются без доказанного владельца. Расширение списка из трёх проверенных целей не обосновано.

[Read-only census](SCABBARD_ASSET_CENSUS_11.md#игровой-результат-2026-11-07) и [поочерёдная изоляция поверх скрытой базы](SCABBARD_RESIDUAL_ISOLATION_12.md#повторный-сеанс--pass-для-поочерёдной-изоляции) завершены. Пользователь подтвердил визуальный вклад spear, staff и dual. Полное покрытие всех шести одновременно остаётся гипотезой до совместной проверки. Старый вывод офлайн-анализа выше описывает состояние доказательств до игровых сеансов.

[scabbard-dynamic-cudgel-01](SCABBARD_DYNAMIC_CUDGEL_13.md#игровой-сеанс-2026-11-07--pass-в-подтверждённом-наборе) — **PASS** для одновременного скрытия и восстановления шести целей, раннего draw, обычных атак в руках, задержки после Sheath, пропуска позднего Sheath и ручного STOP. Production **BLOCKED**. Отмена уже поставленного таймера — игровой PASS 2026-11-08. Повторный Sheath подтверждён в стабе.

## Следующий игровой gate

[Отмена уже поставленного таймера — игровой PASS](SCABBARD_DYNAMIC_CUDGEL_13.md#игровой-pass-отмены-уже-поставленного-таймера--2026-11-08). Принятые визуальный сеанс и отмену таймера повторять не нужно.

[scabbard-freeplay-01](SCABBARD_FREEPLAY_14.md) подтвердил в игре доставку уведомления о смене слота, восстановление диагностики после reload и STOP. Для проверенной смены Blueprint post уже поздний для всей старой группы. Автоматическая запись при свободной игре BLOCKED.

Следующая адресная проверка — [scabbard-universal-01](SCABBARD_UNIVERSAL_15.md). Нужно определить, остаются ли старые привязки актуальными на входе в EndPlay. При разрыве привязки искать более ранний подтверждённый сигнал или независимую маску с безопасным временем жизни. При сохранении привязки отдельно доказать право и возможность снять собственное подавление в этом callback.

Проверки роли `*_use/_unuse` и раннего draw для других семейств нужны для общей маски. Совместимость с CombatHUD/HildaSoftLight/косметическими пакетами и локальный магический VFX проверяются отдельно. Не вводить CI, VERSION, installable artifact или Release без production-механизма и соответствующих gates. Нумерованные/переданные кандидаты неизменяемы.
