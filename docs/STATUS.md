# MagicalScabbards — статус

**По состоянию на 2026-11-06:** локальный checkout и публичный GitHub bootstrap завершены. Первое статическое исследование завершено в ветке `research/scabbard-static-01`.

- Принятая продуктовая цель: отображать штатные ножны Хильды в бою и скрывать вне боя; небольшой магический VFX желателен, но не должен блокировать базовый прототип.
- Предварительно установлен релевантный путь чтения боевого состояния **в другом принятом моде** CombatHUD 0.4.1: `GameGlobal:GetIsBattleState(character)`.
- [Сравнены все 15 пар](SCABBARD_STATIC_RESEARCH_01.md). No Scabbard подменяет их пустыми SkeletalMesh. Установлены штатные шаблоны компонентов и Blueprint-писатель видимости для `scabbard_a/b`.
- **Production gate: BLOCKED.** Открыты фактические владельцы инстансов экипировки, порядок штатных переключений, состав безопасных секций, hide/show+restore и VFX API.
- Production source, установленного runtime, выпущенной версии, бинарной сборки, CI и релиза **нет**; это сознательное ограничение стадии bootstrap.

## Следующий этап

По отдельному разрешению провести узкую read-only проверку инстансов и порядка штатных переключений по [статическому отчёту](SCABBARD_STATIC_RESEARCH_01.md#решение-для-следующего-шага).

## Bootstrap

- Отдельный checkout в группе Asterigos. Сохранён исходный коммит архива `6e8062ca782f2fa72f058a949e7b1e62fc8a052f`.
- Публичный репозиторий и `origin` — [NikichMods/MagicalScabbards](https://github.com/NikichMods/MagicalScabbards). Ветка по умолчанию — [`main`](https://github.com/NikichMods/MagicalScabbards/tree/main), локальная `main` отслеживает `origin/main`. Первый push проверен по [коммиту 5aab668](https://github.com/NikichMods/MagicalScabbards/commit/5aab6683a9e9360070412d44e470282eb8710c97).
- Topics — `game-asterigos`, `nikichmods-mod`.
- Единственный общий источник исследований игры — [NikichMods/Asterigos-Research](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/RESEARCH_INDEX.md).
