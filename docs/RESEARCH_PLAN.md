# MagicalScabbards — следующий исследовательский шаг

**Режим:** research-only; production gate BLOCKED. **Принято 2026-11-06:** источник политики — **вынимание/убирание оружия**, а не боевой getter. Прежние исследования остаются свидетельствами, но не определяют новый продуктовый контракт.

## Не повторять уже принятое

- [SCABBARD_STATIC_RESEARCH_01](https://github.com/NikichMods/MagicalScabbards/blob/9f360eba1dd8eb33eba5e0b6de075c278a664e10/docs/SCABBARD_STATIC_RESEARCH_01.md): 15 оригиналов/замен, пустые SkeletalMesh, отдельные pawn-scabbards, составные *_sheath, штатный Blueprint writer scabbard_on/off.
- [SCABBARD_RUNTIME_RESEARCH_01](https://github.com/NikichMods/MagicalScabbards/blob/3d60cf7ce8725f4fa0efa4b2d589a1ac24c73064/docs/SCABBARD_RUNTIME_RESEARCH_01.md): 6 read-only snapshots, owners и attachment, new pawn при reload; состояния cudgel при одинаковом battle; actions=0 у ограниченного ExecuteAction observer — разрыв наблюдения, а не отрицание вызовов.
- [Asterigos-Research](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/RESEARCH_INDEX.md) — единственный владелец общих проверенных фактов. Baseline Steam 1.09/build 12996889, UE4.27, UE4SS 83330635.

## Вопросы для решения механизма

1. Какой реальный игровой owner/событие/состояние доказывает **начало вынимания** и **окончание убирания** оружия, включая прерывания, смену типа и случаи вне боя? Не принимать название Blueprint action или кнопку за гарантированную стадию.
2. Кто реально пишет bHiddenInGame/bVisible на scabbard_a/b, в каком порядке относительно вынимания/убирания, и почему ранее не наблюдался ExecuteAction callback?
3. Можно ли создать независимое и обратимое подавление видимости всего убранного комплекта, включая scabbard_a/b и подтверждённые компоненты `*_sheath`, не перезаписывая решения игры? Как различать собственную запись и последующие штатные писатели?
4. Какие реальные компоненты образуют убранный комплект **вместе с оружием**, а какие — текущее оружие в руках? Доказать по owner/attachment и фактическому показу. Допускать скрытие целого составного `*_sheath`, если он относится только к убранному комплекту; section visibility изучать лишь при доказанном пересечении с активным оружием.
5. Как отслеживать поколение local pawn и актуальную экипировку без устаревших акторов, как вернуть своё состояние на interrupted/load/map transitions?

## Метод и стоп-условие

Повторно используйте сохранённый static bytecode/evidence и локальные runtime-логи. Только при реальном пробеле подготовьте **один bounded read-only UE4SS observer** на verified local pawn и одном оружейном семействе, с заранее проверенными callback, budget, failure/cleanup и hash source. Никаких глобальных поисков на каждом кадре. Игра запускается/перезапускается **только с разрешения пользователя**. Не изменять visibility, меши, assets, VFX, сохранения или соседние моды.

**Остановить** шаг при подтверждении draw-start и stow-complete (или доказанном блокере), одного candidate owner/consumer и reviewable READY/BLOCKED. Новые reusable game facts — в Asterigos-Research, специфика и доказательства — в MagicalScabbards. Write-test hide/show и VFX только отдельными следующими этапами после нужных gates.
