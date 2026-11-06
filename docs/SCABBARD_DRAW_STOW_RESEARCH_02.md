# MagicalScabbards — draw/stow 02

**BLOCKED · NOT_RUNTIME_TESTED.** Установлены штатная карта cudgel и кандидаты анимационных границ. Для отдельного обратимого write-test ещё нужны живой порядок границ и доказуемое владение маской видимости.

## Статическое доказательство

Steam build 12996889, UE4.27, CUE4Parse 1.2.2. Использованы [runtime 01](https://github.com/NikichMods/MagicalScabbards/blob/3d60cf7ce8725f4fa0efa4b2d589a1ac24c73064/docs/SCABBARD_RUNTIME_RESEARCH_01.md), сохранённые UHT и cooked `Skill_Player` / `TimelineData_PlayerSkill[_2]`. Выборочно прочитаны штатные `Weapon`, `WeaponTypeInfo`, `hilda_AnimBP` и две cudgel-анимации. Сравнение No Scabbard не повторялось.

| Состояние в `/Game/MainContent/Tables/Player/Weapon`, строка `cudgel_mod00` | Штатный класс, слот и узел |
| --- | --- |
| `SheathEquipObjects` | `HildaCudgel_BP_C`, `right_hand`, узел `scabbard_a` |
| `InHandEquipObjects` | тот же класс и слот, узел `cudgel_r_hand`; отдельно `HildaCudgel_Use_BP_C`, слот `scabbard`, узел `scabbard_a` |
| `InventoryEquipObjects` | `HildaCudgel_Unuse_BP_C`, слот `scabbard`, узел `scabbard_a` |
| `FloatingEquipObjects` | основной актор на `dual_l_hand`, вспомогательный `_Use` на `scabbard_a` |

В runtime 01 основной актор сохранял identity и менял видимость двух отдельных компонентов. По таблице класс и слот сохраняются даже при смене узла. Поэтому стыковать нужно **текущий pawn, owner, root socket, asset, компонент и фазу**. Подтверждённый `hilda_cudgel_sheath` — кандидат на целый убранный комплект; основной `SkeletalMesh` в руке исключён. `_Use` предусмотрен в том числе для состояния оружия в руках; `_Unuse` предусмотрен для inventory, его нельзя автоматически считать основным убранным комплектом. Пара `scabbard_a/b` на pawn — отдельные компоненты и отдельные штатные писатели.

- `Weapon.cudgel_mod00` задаёт `SwitchWeaponSkill_Enter=hilda_cudgel_switch_enter` и `SheathWeaponSkill=sheath_cudgel`. Skill входа использует `hilda_cudgel_switch_enter` и содержит timeline `cudgel_in_hand`: на ключе 5 стоит `set weapon in hand`. Это кандидат на перенос оружия после начала, а не доказанный сигнал начала каждого draw.
- `sheath_cudgel` использует анимацию `hilda_cudgel_sheath`, timeline `sheath_cudgel` с несколькими командами рук и floating, в том числе `set weapon in hand` с пустым типом на ключе 37. Отдельный `SkillEndTimelineData=sheath_all` содержит ещё `set weapon in hand` и рассылку `sheath` / `scabbard`. Значения ключей не следует превращать в production-таймер. Команда внутри timeline, конец skill и фактическое завершение показа комплекта могут приходиться на разные границы.
- `/Game/MainContent/Assets/creature/01_character/hilda/hilda_AnimBP` вызывает отражённые native `BaseCharacterAnimInstance:BeginDoSkill` на смещении 68120 и `EndDoSkill` на 67936/69038. Это более прямой наблюдаемый кандидат, чем угадывание по `ExecuteAction`. Два места вызова End не доказывают нормальное завершение: нужен соответствующий skill плюс устойчивый стык с убранным комплектом.
- В предыдущем observer Blueprint hook зарегистрировался после первого снимка и считал только четыре имени для выбранного pawn. `actions=0` не различает недоставленный callback, другую точку dispatch, аргумент, фильтр или маршрут. Причина остаётся неизвестной. Новый observer логирует первое декодирование для каждой native фазы до фильтрации по интересующему skill.

## Один read-only сеанс

Observer `draw-stow-observer-01` использует ручные снимки через EngineTick и pre/post hooks двух native методов штатного анимационного инстанса. Считывает `GetToDoSkill` и `GetDoingSkill` на callback; аргументов у обеих функций нет. Поиск объектов ограничен ручными снимками, выводится только экипировка с текущим owner и root attachment. Бюджет: 3 снимка, 32 callback выбранного anim, 8 кандидатов на класс, 120 секунд после первого снимка, Ctrl+Alt+F10 — остановка. Смена pawn/anim на снимке или ошибка останавливает проверку. Журнал исходного сеанса хранится приватно; публично фиксируются хэш и выжимка.

В безопасном месте вне боя использовать тот же обычный молот. Ctrl+Alt+F9 в устойчивом убранном состоянии → штатно вынуть молот → Ctrl+Alt+F9 когда в руках → штатно убрать → Ctrl+Alt+F9 после завершения. При необходимости завершить Ctrl+Alt+F10. Не требуется бой, reload или смена оружия.

Идентичность observer: SHA-256 "e0c0835119ded15faedb8bea50e9df8e46ed22fec01a97a722915b7db5901a6d". Синтаксис и маршруты native pre/post, декодирования имени, лимита снимков и cleanup проверены в Lua 5.4 со стабами.

## Выбор механизма и стоп

Предпочтительна семантика skill/анимационной фазы с проверкой текущего owner/attachment и устойчивого состояния комплекта. Снимки видимости и `weapon_in_hand/leave_hand` могут подтвердить перенос, но сами не отделяют начало от конца. Ни battle, ни кнопка, ни задержка не дают требуемой границы. Для компонента `_sheath` ранее наблюдалось переключение `bVisible`, для pawn-пары статически подтверждён писатель `bHiddenInGame`: одну и ту же маску нельзя считать независимой на обеих поверхностях. Прежде чем писать, нужно доказать совместимость с writers и восстановление только собственного подавления.

Следующий единственный шаг — один сеанс с observer и проверка доставки/имён skill, порядка callback и трёх снимков. Если нужный путь не доставляет события или граница допускает несколько трактовок, остановиться с конкретным пробелом.
