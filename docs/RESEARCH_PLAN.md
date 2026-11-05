# MagicalScabbards — первый технический этап

**Режим:** research-only; `main` не получает непроверенный runtime-код. До установления owner, перехода combat-state и безопасного управления видимостью production gate = **BLOCKED**.

## Основания, уже подтверждённые для соседних проектов

- [Asterigos-Research / Verified Runtime](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/VERIFIED_RUNTIME.md): Steam 1.09/build 12996889, UE4.27, UE4SS 83330635; безопасное получение owning pawn в рабочем HUD; ограничения ownership/lifecycle.
- [CombatHUD 0.4.1 Scripts/main.lua](https://github.com/NikichMods/CombatHUD/blob/main/Scripts/main.lua): `GameGlobal:GetIsBattleState(character)` читается в принятой игре. Это **проверенный пример чтения**, не доказательство готовности любого нового consumer.
- [HildaSoftLight lighting feasibility](https://github.com/NikichMods/HildaSoftLight/blob/research/lighting-feasibility/docs/LIGHTING_FEASIBILITY.md): сохранённые SCS `hilda_BP` и отражённые методы `SceneComponent:SetVisibility/SetHiddenInGame`, lifecycle-границы. Материалы по свету **не** доказывают принадлежность ножен к отдельному SceneComponent.
- [NO_SCABBARD_REFERENCE.md](NO_SCABBARD_REFERENCE.md): 15 названий ресурсов из стороннего пакета, но никаких доказанных runtime-owners.

## Минимальные вопросы, способные изменить архитектуру

1. Для каждой из 15 IoStore-записей сравнить **оригинальный** игровой ресурс с его заменой в No Scabbard: тип (skeletal/static mesh, skeleton, materials), фактические отличия и наличие геометрии; не предполагать «уменьшение масштаба» по внешнему виду.
2. Выяснить, где эти ресурсы используются в `hilda_BP`, оружейных actors/Blueprint и во время equip/unequip. Установить, есть ли отдельные **ножны** как component/mesh/section, не смешивая их с оружием в руках, `_use/_unuse` или общей одеждой.
3. Для выбранного runtime-owner установить конкретную цепочку object → owner → asset/section, штатные native/Blueprint visibility writers, жизненный цикл при смене оружия/загрузке/пересоздании pawn.
4. Сопоставить возможные способы: отдельный `SetVisibility` / `SetHiddenInGame`, material-section visibility, material fade, замена ассетов. Сначала выбрать минимальный способ, соответствующий критериям, и документировать отказ от более опасных вариантов.
5. После статического evidence, если всё ещё нужно, подготовить **один ограниченный** runtime-probe с read-only enumerations и строгими бюджетами/cleanup по `RUNTIME_TEST_HARNESS.md`; только затем отдельный minimal write-test hide/show с rollback после reviewable READY.
6. Для VFX отдельно проверить существующие ни к чему не привязанные asset/particle emitters или допустимый собственный transient component; не создавать эффекты или освещение раньше доказанного позиционирования ножен.

## Очередность и стоп-условие

Этап A — **статическое** сопоставление No Scabbard и оригиналов в установленной игре. Для каждого необходимого доказательства фиксировать asset path, owner/class, baseline, exact hashes/provenance, вывод и неизвестное. Не публиковать материалы игры, сторонние binary mods, полные дампы или приватные пути.

Этап B — **read-only** runtime-target discovery (только если static не даёт достаточного ответа). Перейти к реализации лишь когда установлен конкретный набор компонентов/секций и безопасная стратегия изменения/восстановления, а не потому, что Unreal API в целом поддерживает `SetVisibility`.

**Остановить первый этап** при наличии проверяемого выбора владельца ножен + минимального способа переключения, или если доказан конкретный блокер. Зафиксировать `READY/BLOCKED` и узкий дальнейший шаг; в общий Asterigos-Research переносить только подтверждённые reusable host-факты со ссылкой на первичное evidence. Не запускать длительный общий поиск неопределённого масштаба.
