# MagicalScabbards — следующий исследовательский шаг

**Режим:** research-only; production gate BLOCKED. **Принято 2026-11-06:** источник политики — **вынимание/убирание оружия**, а не боевой getter; немедленный показ при draw и однократное скрытие **через 2 секунды после `EquipModeChange(Sheath)`** только при повторном подтверждённом stowed. Не искать точное завершение stow-анимации для этой политики. Прежние исследования остаются свидетельствами, но не определяют новый продуктовый контракт.

## Не повторять уже принятое

- [SCABBARD_STATIC_RESEARCH_01](https://github.com/NikichMods/MagicalScabbards/blob/9f360eba1dd8eb33eba5e0b6de075c278a664e10/docs/SCABBARD_STATIC_RESEARCH_01.md): 15 оригиналов/замен, пустые SkeletalMesh, отдельные pawn-scabbards, составные *_sheath, штатный Blueprint writer scabbard_on/off.
- [SCABBARD_RUNTIME_RESEARCH_01](https://github.com/NikichMods/MagicalScabbards/blob/3d60cf7ce8725f4fa0efa4b2d589a1ac24c73064/docs/SCABBARD_RUNTIME_RESEARCH_01.md): 6 read-only snapshots, owners и attachment, new pawn при reload; состояния cudgel при одинаковом battle; actions=0 у ограниченного ExecuteAction observer — разрыв наблюдения, а не отрицание вызовов.
- [Asterigos-Research](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/RESEARCH_INDEX.md) — единственный владелец общих проверенных фактов. Baseline Steam 1.09/build 12996889, UE4.27, UE4SS 83330635.

## Вопросы для решения механизма

1. Какой достаточно ранний draw-сигнал позволяет **сразу показать комплект** для поддерживаемых маршрутов, включая прерывание и случаи вне боя? Для первого удара cudgel уже есть кандидат. Для stow использовать доказанный `EquipModeChange(Sheath)` плюс **2 секунды** с guard, а не искать точный stow-animation end.
2. Какой независимый и обратимый канал подавления доступен для подтверждённого `HildaCudgel_BP_C.hilda_cudgel_sheath`? `bVisible` имеет штатного writer; `bHiddenInGame` пока кандидат, а не доказанная независимость. Pawn scabbard_a/b не включать в первый эксперимент по аналогии.
3. Как реализовать одноразовый таймер, его отмену/инвалидацию при новом draw, повторной Sheath, смене оружия/pawn, unknown и reload и rollback **только собственных записей** на том же живом компоненте?
4. Какие реальные компоненты образуют убранный комплект **вместе с оружием**, а какие — текущее оружие в руках? Доказать по owner/attachment и фактическому показу. Допускать скрытие целого составного `*_sheath`, если он относится только к убранному комплекту; section visibility изучать лишь при доказанном пересечении с активным оружием.
5. Как отслеживать поколение local pawn и актуальную экипировку без устаревших акторов, как вернуть своё состояние на interrupted/load/map transitions?

## Метод и стоп-условие

Повторно используйте сохранённый static bytecode/evidence и локальные runtime-логи. Только при реальном пробеле подготовьте **один bounded read-only UE4SS observer** на verified local pawn и одном оружейном семействе, с заранее проверенными callback, budget, failure/cleanup и hash source. Никаких глобальных поисков на каждом кадре. Игра запускается/перезапускается **только с разрешения пользователя**. Не изменять visibility, меши, assets, VFX, сохранения или соседние моды.

**Остановить** шаг при подтверждении раннего draw для узкого сценария, Sheath commit, независимости маски/rollback и guard для 2-секундного timer (или доказанном блокере) с reviewable READY/BLOCKED. Новые reusable game facts — в Asterigos-Research, специфика и доказательства — в MagicalScabbards. Write-test hide/show и VFX только отдельными следующими этапами после нужных gates.

## Пересмотр способа скрытия: пространство решений (2026-11-07, пока гипотезы)

После [Delayed hide gate 06](https://github.com/NikichMods/MagicalScabbards/blob/7a73588daef189c5d20d3724b1044124c6e63515/docs/SCABBARD_DELAYED_HIDE_GATE_06.md) **не считать доказательство эксклюзивного владельца `bHiddenInGame` единственным маршрутом**. Перед новым аппаратным native trace сравнить две поверхности одного live `hilda_cudgel_sheath`: **A** кооперативный `SetVisibility` по уже доказанным штатным `EquipModeChange` writers, **B** отдельный `SetHiddenInGame` с ограниченным rollback. **C** — штатные pawn scabbard_a/b и `scabbard_on/off` как другие части полного визуального комплекта; не путать с cudgel sheath. Actor-wide hide скрывает также held weapon; пустые replacement assets мешают мгновенному возврату. Техническое предпочтение A/B ещё не принято. Выбирать наименьший безопасный механизм и самый короткий проверяющий тест, а не максимальную глубину reverse engineering. Продуктовые требования 2000 мс и мгновенного появления неизменны. **Production BLOCKED**, никаких записей в игру без отдельного gate и разрешения.
