# MagicalScabbards — локальный контракт

Самостоятельный мод для **Asterigos: Curse of the Stars**; целевой владелец — `NikichMods/MagicalScabbards`. Следовать актуальным [NikichMods/DevRules/WORKING_RULES.md](https://github.com/NikichMods/DevRules/blob/main/WORKING_RULES.md); при создании проекта — `PROJECT_BOOTSTRAP.md`, при исследовании/изменении поведения — `ENGINEERING_RULES.md`, при Git — `GIT_WORKFLOW.md`, при работе локального Codex — `CODEX_WORKFLOW.md`; по применимости — `RUNTIME_INTEGRATION.md`, `RUNTIME_TEST_HARNESS.md`, `CI_POLICY.md`, `LICENSE_POLICY.md`. Исключений нет.

## Владение и источники истины

- Этот репозиторий — единственный владелец требований, архитектурных решений, production-кода, тестов, статуса, версий и приёмки MagicalScabbards.
- **Единый общий Research по игре:** [NikichMods/Asterigos-Research](https://github.com/NikichMods/Asterigos-Research), точка входа [docs/RESEARCH_INDEX.md](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/RESEARCH_INDEX.md). Переиспользовать подтверждённые факты, новые переносимые результаты промотировать туда со ссылкой на источник. Не копировать изменяемый статус этого мода в Research.
- Локальные канонические файлы: [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md), [docs/STATUS.md](docs/STATUS.md), [docs/RESEARCH_PLAN.md](docs/RESEARCH_PLAN.md); исследовательские исходные свидетельства — [docs/NO_SCABBARD_REFERENCE.md](docs/NO_SCABBARD_REFERENCE.md).
- Общий принятый baseline других модов: **Steam 1.09 / build 12996889, UE4.27, Windows x64, UE4SS v3.0.1-1181-g83330635**. Это **не** подтверждение работы MagicalScabbards на данном или любом другом окружении.
- [CombatHUD 0.4.1](https://github.com/NikichMods/CombatHUD/blob/CombatHUD-v0.4.1/Scripts/main.lua#L380) использует `GameGlobal:GetIsBattleState(character)`; переносимость пути чтения необходимо перепроверить в контексте владельца этого мода. Не добавлять зависимость от CombatHUD без обоснования.

## Границы и инварианты

- Цель — **только видимость ножен** на Хильде с учётом подтверждённого состояния боя; не скрывать наугад весь weapon mesh, `_use/_unuse` или компоненты одежды. Не подменять исходные ножны микромешем в production, если доступен безопасный runtime-путь.
- Не изменять положение, размер, анимации, эффекты, механику, характеристики, боевое состояние, ввода или отображение активного оружия в руках. Не менять ресурсы другого мода и не конфликтовать намеренно с пользовательскими косметическими модами.
- Невалидный/неопределённый pawn, UI-only, переход уровня, смерть, кат-сцена, смена оружия и завершение работы — lifecycle-гейты. Не делать запись в неподтверждённый объект; восстанавливать **только собственные** изменения там, где объект ещё валиден.
- Магический VFX — отдельный кандидат после подтверждения базового hide/show; эффект не должен засвечивать окружение и запускаться каждый тик.

## Инженерный и Git-контракт

- **Production gate: BLOCKED** до доказательства точного owner и состава компонентов ножен, native writers/refresh, корректного переключения видимости и безопасного rollback. До того — ограниченные read-only проверки и исследовательские ветки.
- `main` — стабильный проектный контракт и **только принятый runtime**; `research/*` — исследование, `dev/*` — непроверенный кандидат. Изменения документации допустимы в `main` без релиза. При изменении поведения выполнить `ENGINEERING_RULES.md` READY/BLOCKED, затем игры/runtime acceptance до продвижения.
- Не создавать `VERSION`, установочные пакеты, автоматические сборки, CI и Releases, пока не определён исполняемый механизм и проверяемый consumer. Нумерованные кандидаты и переданные артефакты неизменяемы.
- Предпочтительно отключение через `enabled.txt`/штатный UE4SS loader после исследования выбранного маршрута, без вмешательства в соседние моды. До проверки установка не предлагается.

## Лицензия

Оригинальный исходный код/документы проекта: **MPL-2.0**, полный текст в [LICENSE](LICENSE), объем прав — [LICENSING.md](LICENSING.md). Для будущих оригинальных исходников использовать `SPDX-License-Identifier: MPL-2.0`. Не коммитить proprietary game assets, пакеты No Scabbard, дампы игрового контента, приватные machine paths, логи с персональными данными, ключи и другие секреты.
