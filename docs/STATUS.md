# MagicalScabbards — статус

**По состоянию на 2026-11-06:** локальный checkout и публичный GitHub bootstrap завершены. Проект готов к первому статическому исследованию после отдельного запуска задания.

- Принятая продуктовая цель: отображать штатные ножны Хильды в бою и скрывать вне боя; небольшой магический VFX желателен, но не должен блокировать базовый прототип.
- Предварительно установлен релевантный путь чтения боевого состояния **в другом принятом моде** CombatHUD 0.4.1: `GameGlobal:GetIsBattleState(character)`.
- Из архива пользователя `No Scabbard` статически извлечены имена 15 заменяемых ресурсов; точный эффект на cooked meshes и сопоставление с оригинальными ресурсами **не проверены**.
- **Production gate: BLOCKED.** Нет доказанного runtime-owner ножен, списка исключительно scabbard-компонентов/секций, безопасного hide/show+restore и VFX API.
- Production source, установленного runtime, выпущенной версии, бинарной сборки, CI и релиза **нет**; это сознательное ограничение стадии bootstrap.

## Следующий этап

Проверить локально разницу между 15 ресурсами No Scabbard и оригиналами, владельцев/привязку ножен к `hilda_BP` и механизм переключения. Подробности и stop-condition: [RESEARCH_PLAN.md](RESEARCH_PLAN.md); готовое узкое задание: [CODEX_RESEARCH_TASK.md](CODEX_RESEARCH_TASK.md).

## Bootstrap

- Отдельный checkout в группе Asterigos. Сохранён исходный коммит архива `6e8062ca782f2fa72f058a949e7b1e62fc8a052f`.
- Публичный репозиторий и `origin` — [NikichMods/MagicalScabbards](https://github.com/NikichMods/MagicalScabbards). Ветка по умолчанию — [`main`](https://github.com/NikichMods/MagicalScabbards/tree/main), локальная `main` отслеживает `origin/main`. Первый push проверен по [коммиту 5aab668](https://github.com/NikichMods/MagicalScabbards/commit/5aab6683a9e9360070412d44e470282eb8710c97).
- Topics — `game-asterigos`, `nikichmods-mod`.
- Единственный общий источник исследований игры — [NikichMods/Asterigos-Research](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/RESEARCH_INDEX.md).
