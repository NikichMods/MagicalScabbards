# MagicalScabbards — статическое исследование 01

**2026-11-06 · Production gate: BLOCKED.** Сопоставлены 15 из 15 ресурсов. Для всех найдены штатные Blueprint-шаблоны компонентов. Открыты фактическое владение инстансами экипировки, порядок штатных переключений и безопасное восстановление видимости.

## Входы и метод

- Оригиналы — установленный Steam AppID `1731070`, build `12996889` по локальному манифесту, UE4.27. Читался только верхний уровень штатного `Paks`, без `~mods`. SHA-256 оригинального `pakchunk0-WindowsNoEditor.utoc` — `0e9d27f84b97f24651ae1ca0ed38facad171e620702cab08198b14b56e52513e`.
- Замены — отдельный provider с пакетом No Scabbard и штатным `global.utoc/.ucas` для script-object metadata. SHA-256 RAR и всех трёх контейнеров совпали с [первичной инвентаризацией](NO_SCABBARD_REFERENCE.md). Оригинальный `pakchunk0` в provider замен не добавлялся.
- [CUE4Parse](https://github.com/FabianFG/CUE4Parse) 1.2.2, `GAME_UE4_27`, локальный Oodle 6. Для каждой пары прочитаны `USkeletalMesh`, `ImportedBounds`, `Skeleton`, `PhysicsAsset`, `SkeletalMaterials`, `LODModels` и render sections. Для владельцев проверены ссылки `SkeletalMesh` в SCS/шаблонах и Blueprint bytecode с `ReadScriptData=true`. Новый экспорт `hilda_BP` совпал по SHA-256 с сохранённым — `1e293e34eddd98dc814d85087477a7355f048ac46f60d758411c3aa7ea231a56`.
- Игра не запускалась. Установка и пакеты использовались только для чтения.

## Сравнение всех пар

Точный корень cooked-путей — `Genesis/Content/MainContent/Assets/creature/03_weapon/`. Все 30 объектов прочитались как `SkeletalMesh`. У каждого оригинала один читаемый LOD0 с геометрией и ссылка на одноимённый `<имя ресурса>_Skeleton`. У **каждой из 15 замен** нулевой `ImportedBounds.BoxExtent`, отсутствуют ссылки на Skeleton и PhysicsAsset, один пустой material slot, LOD помечен `SkipLod`, без секций и вершин. Это подмена целых ресурсов пустыми мешами. Точное поведение при загрузке патча в игре в этом исследовании не проверялось.

В таблице число рядом с материалом — количество треугольников его секции в оригинальном LOD0, порядок соответствует секциям. `shell` = `hilda_scabbard_mat`, `fx` = `hilda_dual_FX_mat`, `light` = `M_Light`.

| Ресурс | Оригинальные секции |
| --- | --- |
| `hilda_cudgel_sheath.uasset` | shell 212, fx 196, `hilda_cudgel_mat` 676 |
| `hilda_cudgel_unuse.uasset` | light 440, shell 364 |
| `hilda_cudgel_use.uasset` | shell 212, fx 196 |
| `hilda_dual_sheath.uasset` | `hilda_dualblade_mat` 1960, fx 388, shell 196 |
| `hilda_dual_unuse.uasset` | shell 280, light 640 |
| `hilda_dual_use.uasset` | fx 388, shell 196 |
| `hilda_scabbard_A.uasset` | shell 4464, `hilda_scabbard_fx_mat` 676 |
| `hilda_scabbard_B.uasset` | shell 1760 |
| `hilda_shield_sheath.uasset` | `hilda_shield_sword_02_mat` 2109 |
| `hilda_spear_sheath.uasset` | `hilda_spear_mat` 2078, fx 384, shell 184 |
| `hilda_spear_unuse.uasset` | light 564, shell 376 |
| `hilda_spear_use.uasset` | fx 384, shell 184 |
| `hilda_staff_sheath.uasset` | `hilda_staff_mat` 1724, shell 216, fx 380 |
| `hilda_staff_unuse.uasset` | shell 352, light 728 |
| `hilda_staff_use.uasset` | shell 216, fx 380 |

## Проверенная карта владельцев

- `/Game/MainContent/Act/Character_BP/hilda_BP`: `hilda_BP_C.scabbard_a` и `.scabbard_b` — самостоятельные `SkeletalMeshComponent`, SCS nodes 10/11, дочерние к штатному `CharacterMesh0`, точки крепления `scabbard_a` и `scabbard_b`. Их шаблоны ссылаются на `hilda_scabbard_A` и `hilda_scabbard_B` соответственно.
- `hilda_BP_C.ExecuteAction` входит в `ExecuteUbergraph_hilda_BP` по смещению 8228. Ветви `scabbard_on` и `scabbard_off` вызывают `SetHiddenInGame(false, false)` по смещениям 11582/11616 и `SetHiddenInGame(true, false)` по 11651/11685 соответственно. Оба компонента имеют штатного писателя. Действия `weapon_in_hand` и `weapon_leave_hand` имеют отдельные ветви (11460 и 11521), поэтому боевой статус сам по себе не описывает штатное состояние ножен.
- В `/Game/MainContent/Act/Item_BP/` пять отдельных SCS-компонентов `hilda_<тип>_sheath` с одноимёнными мешами принадлежат `HildaCudgel_BP_C`, `HildaDualMain_BP_C`, `HildaShield_BP_C`, `HildaSpear_BP_C` и `HildaStaff_BP_C`. В каждом классе есть отдельный `SkeletalMesh` с основным мешем оружия. У dual дополнительно прочитаны `hilda_dualblade_mesh` на main и `hilda_dualoff_mesh` на отдельном `HildaDualOff_BP_C`.
- В том же каталоге у `Hilda{Cudgel,Dual,Spear,Staff}_{Use,Unuse}_BP_C` основной компонент `SkeletalMesh` ссылается на соответствующий `hilda_<тип>_{use,unuse}`. Все 13 целевых классов экипировки наследуют `/Game/MainContent/Template/BaseBlueprint/BaseEquipment_BP`. Проверка этих 13 Blueprint и базы не нашла прямых вызовов `SetHiddenInGame`, `SetVisibility` или `SetSkeletalMesh` в их декодированном bytecode. Кто создаёт и переключает реальные инстансы, в том числе из native-кода, остаётся открытым.

## Решение для следующего шага

- **Component visibility** — первый кандидат для `scabbard_a/b`, поскольку штатный Blueprint уже переключает именно эти два компонента без propagation. Для оружейных `*_sheath` само наличие отдельного компонента недостаточно: у четырёх мешей есть секции с материалом оружия, а щит использует единственную секцию с материалом щита/меча. Скрытие целого компонента затронет и эти секции.
- **Section visibility** имеет смысл только после привязки конкретных секций к требуемой геометрии на нужном LOD и проверки доступного обратимого API. Имя материала помогает сузить поиск, но не доказывает визуальную роль секции. Основные компоненты `_use/_unuse` исключены из первого кандидата.
- **Asset replacement** объясняет способ No Scabbard. Пустая замена убирает все секции и не даёт восстановить штатную геометрию простым переключением видимости.

Узкая следующая проверка после отдельного разрешения — read-only наблюдение за `scabbard_a/b` и одним оружейным семейством с `_sheath/_use/_unuse`. На валидном pawn сверить класс, owner, asset, attachment, фактические `bHiddenInGame` и `bVisible` до и после штатного `scabbard_on/off`, вынимания/убирания оружия и пересоздания владельца при загрузке. Сопоставить порядок с боевым состоянием. Остановиться после одной воспроизводимой последовательности с привязкой писателя к инстансу или при конкретном разрыве цепочки. Для записи видимости ещё нужны граница побочных эффектов, правила сосуществования со штатным писателем и восстановление только собственного состояния на живом инстансе. VFX остаётся отдельным этапом.
