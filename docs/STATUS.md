# MagicalScabbards — текущий статус

**2026-11-06 · Research; production gate: BLOCKED.** Самостоятельный публичный репозиторий NikichMods/MagicalScabbards и организационный bootstrap готовы. Runtime production-кода, принятой тестовой версии, релиза и CI нет.

## Новая принятая концепция — 2026-11-06

**Видимость всего убранного комплекта (ножны и оружие в них) зависит от оружия, а не боя.** Начало вынимания → **показать немедленно** и отменить pending hide; в руках/при убирании → видимо; `EquipModeChange(Sheath)` → запустить **таймер 2 секунды**, не скрывая сразу; по истечении → скрыть **только при повторно подтверждённом текущем stowed**. Требование точного сигнала конца stow-анимации отменено. Прежние правила «бой/вне боя» и 1,5 с после боя отменены. Канонический контракт: [REQUIREMENTS.md](REQUIREMENTS.md). Магический VFX — отдельный следующий этап после функциональной проверки.

## Доказано

- [Static 01](https://github.com/NikichMods/MagicalScabbards/blob/9f360eba1dd8eb33eba5e0b6de075c278a664e10/docs/SCABBARD_STATIC_RESEARCH_01.md): сравнение 15/15 ресурсов, No Scabbard = пустые SkeletalMesh, отдельные scabbard_a/b, штатные scabbard_on/off writers, составные *_sheath.
- [Runtime 01](https://github.com/NikichMods/MagicalScabbards/blob/3d60cf7ce8725f4fa0efa4b2d589a1ac24c73064/docs/SCABBARD_RUNTIME_RESEARCH_01.md): владельцы и attachments на текущем pawn, новые экземпляры после load, разные состояния cudgel при том же значении battle. Запрос на ExecuteAction callback дал actions=0, что оставляет неизвестным фактический путь событий.
- Общие факты промотированы в [Asterigos-Research](https://github.com/NikichMods/Asterigos-Research/commit/577a4f6ea311b94f44df06456bd43f898e946f97).

## Блокеры до реализации

1. Ранний draw для поддерживаемых маршрутов: первый удар cudgel имеет кандидат `BeginDoSkill` pre, другие маршруты пока не покрыты.
2. Независимая обратимая маска только подтверждённого `hilda_cudgel_sheath`: `bVisible` имеет штатного writer, пригодность `bHiddenInGame` и rollback не доказаны. Pawn `scabbard_a/b` не включать в первый тест по аналогии.
3. Одноразовый 2-секундный таймер, отмена при draw/смене экипировки/lifecycle, повторная проверка pawn/actor/component/asset/socket перед hide и восстановление только собственной записи. **Точный конец stow-анимации не блокер.**
4. Комплекты других семейств и проверка совместимости — отдельные этапы; VFX после функционального принятия.

## Следующий шаг

[Cooperative-cudgel-01](https://github.com/NikichMods/MagicalScabbards/blob/1b4d36f61836900a8e81c18826259ed90da4777b/docs/RESEARCH_PLAN.md#результат-cooperative-cudgel-01--2026-11-07): ограниченный игровой write-test уже проведён. **Частичный runtime PASS**: hide после 2016 мс, ранний release до InHand, отмена pending hide подтверждены по логу. **Не принято:** видимое изменение комплекта (пользователь не заметил разницы), ручной STOP при active mask, обычная InHand атака и overlap раннего draw с поздним Sheath post. Источник `cooperative-cudgel-01` заморожен, не переписывать. **Production BLOCKED**.

`cooperative-cudgel-02` — [игровой сеанс завершён](RESEARCH_PLAN.md#результат-игрового-сеанса-02--2026-11-07). **PASS** для hide через 2016 мс и ручного STOP с активной маской. По видео оранжевый нижний фрагмент исчезает и возвращается, основная деталь остаётся видимой. Обычная атака в руках, draw с активной маской и поздний Sheath в 02 остаются **NOT_TESTED в игре**. Следующий вопрос — принадлежность оставшейся геометрии на том же молоте. **Production BLOCKED**.

[Визуальный состав 08](SCABBARD_VISUAL_INVENTORY_08.md): большой диск и корпус соответствуют форме A; B — отдельная короткая накладка, её видимый вклад не изолирован. [Отдельный A/B harness](SCABBARD_VISUAL_ISOLATION_AB_09.md) прошёл Lua 5.4 стабы. **READY** для одного ограниченного сеанса после разрешения, **runtime NOT_TESTED**, **production BLOCKED**.

## Организация

- GitHub: [NikichMods/MagicalScabbards](https://github.com/NikichMods/MagicalScabbards), default main; topics game-asterigos, nikichmods-mod.
- Исходный bootstrap: [6e8062ca](https://github.com/NikichMods/MagicalScabbards/commit/6e8062ca782f2fa72f058a949e7b1e62fc8a052f); GitHub bootstrap: [5aab6683](https://github.com/NikichMods/MagicalScabbards/commit/5aab6683a9e9360070412d44e470282eb8710c97).
- Общие доказательства живут в [едином Asterigos-Research](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/RESEARCH_INDEX.md); архивные результаты static/runtime не изменены.
