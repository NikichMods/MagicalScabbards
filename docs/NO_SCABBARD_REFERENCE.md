# No Scabbard — локально исследованный сторонний reference

**Дата первичной инвентаризации:** 2026-11-06. Пользователь предоставил оригинальный архив `3. Optional - No scabbard.rar`. Файл **не включён** в публичный репозиторий и не лицензирован NikichMods. Содержимое обследовано в режиме чтения; runtime-проверка и сравнение с оригинальной установленной игрой не выполнялись.

## Вход и точная идентичность

| Артефакт | Размер, байт | SHA-256 |
|---|---:|---|
| Переданный RAR | 6 455 | `d8cb23b02d9f48cc37e8499b754fdb1d0e2bf7add55899a30db828fcc85cc8f3` |
| `pakchunk95-WindowsNoEditor_P.pak` | 339 | `a3c4ecf04b8edbb88fa5fad1058aed5611febb3bcac3c9c8f3aa1af314d44a13` |
| `pakchunk95-WindowsNoEditor_P.utoc` | 1 955 | `cef03f388c165dd124581728f513c3198e343d29c9f4b8b07f2cc2720078726b` |
| `pakchunk95-WindowsNoEditor_P.ucas` | 60 352 | `7c4d65b95d27e181cde83c26e4dc18490c37f255d50e4a28eed88e546527a623` |

В строках `.utoc` виден корень `../../../Genesis/Content/MainContent/Assets/creature/03_weapon/` и следующие **15 имён `.uasset`**:

```text
hilda_cudgel_sheath.uasset
hilda_cudgel_unuse.uasset
hilda_cudgel_use.uasset
hilda_dual_sheath.uasset
hilda_dual_unuse.uasset
hilda_dual_use.uasset
hilda_scabbard_A.uasset
hilda_scabbard_B.uasset
hilda_shield_sheath.uasset
hilda_spear_sheath.uasset
hilda_spear_unuse.uasset
hilda_spear_use.uasset
hilda_staff_sheath.uasset
hilda_staff_unuse.uasset
hilda_staff_use.uasset
```

В `.utoc` видна строка `Oodle`; сырые printable strings из `.ucas` содержат, среди прочего, название `hilda_cudgel_sheath`, `Escabbard_A_Skeleton` и термины меша. **Это не является корректным декодированием всех cooked-объектов.**

## Достоверно и недостоверно

**Достоверно:** сторонний IoStore-пакет перечисляет конкретные game resource paths; размер каждого файла и SHA-256 зафиксированы. Он указывает на предметную область оружия, а не только на общий body/costume texture pack.

**Остаётся неизвестным:** какие 15 записей действительно изменяют только ножны, каким именно способом скрывается geometry, есть ли scale-to-zero/пустой mesh/замена LOD, являются ли они отдельными runtime-компонентами, какие названия соответствуют ножнам каждого вида оружия, и что происходит с `_use/_unuse` и различными костюмами. Нельзя выводить механизм только из имён/размеров/визуального эффекта.

**Ограничение на распространение:** не добавлять оригинальный RAR, `.pak`, `.ucas`, `.utoc`, извлечённые `.uasset` или материал из сторонней работы в публичный GitHub без правового основания. Следующая проверка — сравнение с оригинальными ассетами в локальной установленной версии и документирование только разрешённых выводов/хэшей.
