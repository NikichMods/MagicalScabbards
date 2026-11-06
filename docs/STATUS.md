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
2. Обратимое управление только подтверждённого `hilda_cudgel_sheath`: `bVisible` имеет штатного writer, для ограниченного теста выбрана кооперация с ним; фактический rollback ещё не проверен. Pawn `scabbard_a/b` не включать в первый тест по аналогии.
3. Одноразовый 2-секундный таймер, отмена при draw/смене экипировки/lifecycle, повторная проверка pawn/actor/component/asset/socket перед hide и восстановление только собственной записи. **Точный конец stow-анимации не блокер.**
4. Комплекты других семейств и проверка совместимости — отдельные этапы; VFX после функционального принятия.

## Следующий шаг

Выбран A, кооперативный SetVisibility только на stock cudgel sheath. **Research write-test READY к подготовке** по [ограниченному протоколу](RESEARCH_PLAN.md#выбор-механизма-и-первый-обратимый-тест--2026-11-07), с обязательными стабами до запуска и отдельным разрешением. Кандидат cooperative-cudgel-01 подготовлен, Lua-стабы прошли. Игровой сеанс и runtime acceptance ожидаются. **Production BLOCKED**.

## Организация

- GitHub: [NikichMods/MagicalScabbards](https://github.com/NikichMods/MagicalScabbards), default main; topics game-asterigos, nikichmods-mod.
- Исходный bootstrap: [6e8062ca](https://github.com/NikichMods/MagicalScabbards/commit/6e8062ca782f2fa72f058a949e7b1e62fc8a052f); GitHub bootstrap: [5aab6683](https://github.com/NikichMods/MagicalScabbards/commit/5aab6683a9e9360070412d44e470282eb8710c97).
- Общие доказательства живут в [едином Asterigos-Research](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/RESEARCH_INDEX.md); архивные результаты static/runtime не изменены.
