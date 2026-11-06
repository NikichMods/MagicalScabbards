# MagicalScabbards — текущий статус

**2026-11-06 · Research; production gate: BLOCKED.** Самостоятельный публичный репозиторий NikichMods/MagicalScabbards и организационный bootstrap готовы. Runtime production-кода, принятой тестовой версии, релиза и CI нет.

## Новая принятая концепция — 2026-11-06

**Видимость всего убранного комплекта (ножны и оружие в них) зависит от состояния оружия, а не от состояния боя.** Полностью убрано → скрыто; начало вынимания → показать; в руках и при убирании → видимо; завершено убирание → скрыть. Прежние правила «бой/вне боя» и 1,5 с после боя отменены. Канонический контракт: [REQUIREMENTS.md](REQUIREMENTS.md). Магический VFX — отдельный следующий этап после функциональной проверки.

## Доказано

- [Static 01](https://github.com/NikichMods/MagicalScabbards/blob/9f360eba1dd8eb33eba5e0b6de075c278a664e10/docs/SCABBARD_STATIC_RESEARCH_01.md): сравнение 15/15 ресурсов, No Scabbard = пустые SkeletalMesh, отдельные scabbard_a/b, штатные scabbard_on/off writers, составные *_sheath.
- [Runtime 01](https://github.com/NikichMods/MagicalScabbards/blob/3d60cf7ce8725f4fa0efa4b2d589a1ac24c73064/docs/SCABBARD_RUNTIME_RESEARCH_01.md): владельцы и attachments на текущем pawn, новые экземпляры после load, разные состояния cudgel при том же значении battle. Запрос на ExecuteAction callback дал actions=0, что оставляет неизвестным фактический путь событий.
- Общие факты промотированы в [Asterigos-Research](https://github.com/NikichMods/Asterigos-Research/commit/577a4f6ea311b94f44df06456bd43f898e946f97).

## Блокеры до реализации

1. Надёжные живые сигналы **начала вынимания и завершения убирания**, их owner и порядок относительно штатных writers видимости.
2. Безопасное обратимое управление компонентами scabbard_a/b без борьбы с игрой.
3. Разграничение убранного комплекта и активного оружия в руках для разных семейств. Составные `*_sheath` можно скрывать целиком, если они относятся к убранному комплекту; section-level разделение не требуется без доказанной необходимости.
4. Новые pawn/акторы после загрузки/смены оружия и безопасный rollback; далее отдельный VFX.

## Следующий шаг

[Draw/stow 02](SCABBARD_DRAW_STOW_RESEARCH_02.md): статическая карта cudgel и анимационные кандидаты установлены. Нужен один пользовательский read-only сеанс для проверки доставки и порядка сигналов.

## Организация

- GitHub: [NikichMods/MagicalScabbards](https://github.com/NikichMods/MagicalScabbards), default main; topics game-asterigos, nikichmods-mod.
- Исходный bootstrap: [6e8062ca](https://github.com/NikichMods/MagicalScabbards/commit/6e8062ca782f2fa72f058a949e7b1e62fc8a052f); GitHub bootstrap: [5aab6683](https://github.com/NikichMods/MagicalScabbards/commit/5aab6683a9e9360070412d44e470282eb8710c97).
- Общие доказательства живут в [едином Asterigos-Research](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/RESEARCH_INDEX.md); архивные результаты static/runtime не изменены.
