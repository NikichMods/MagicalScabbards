# MagicalScabbards — текущий статус

**2026-11-09 · Research; production gate: BLOCKED.** Публичный проект и исследовательские ветки существуют; **принятого production runtime, установочной версии, CI и релиза нет**. Документационные результаты исследовательских веток допустимо отражать в `main`, но их экспериментальный Lua не является принятым runtime.

## Цель и принятое поведение

Комплект скрывается после **3000 мс непрерывно подтверждённого stowed** и отпускается с начала draw. Боевой статус не участвует. Канонический контракт в [REQUIREMENTS.md](REQUIREMENTS.md). Новый [State Reconcile 01](SCABBARD_STATE_RECONCILE_01.md) содержит офлайн-ядро и read-only наблюдатель. Подавление в игре пока BLOCKED.

## Доказанные результаты и точные пределы

- [Static 01](https://github.com/NikichMods/MagicalScabbards/blob/9f360eba1dd8eb33eba5e0b6de075c278a664e10/docs/SCABBARD_STATIC_RESEARCH_01.md): сторонний No Scabbard заменяет **15/15** известных оригинальных weapon/scabbard ресурсов пустыми SkeletalMesh, включая `*_sheath`, `*_use/_unuse`, `hilda_scabbard_A/B`. Выявлены SCS/Blueprint attachments и writers; статическая замена не доказывает фактическое отображение конкретной детали в игре.
- [Runtime 01](https://github.com/NikichMods/MagicalScabbards/blob/3d60cf7ce8725f4fa0efa4b2d589a1ac24c73064/docs/SCABBARD_RUNTIME_RESEARCH_01.md): реальные владельцы/attachments, новые экземпляры после reload, несовпадение battle и equip state; в одном снимке после reload `_Unuse` прикреплён к pawn, что требует проверки для остаточной геометрии, но **не доказывает** её принадлежность.
- [Cooperative-cudgel-01/02](https://github.com/NikichMods/MagicalScabbards/blob/24c581305210260ae8e36ea0c4f172323b5312bc/docs/RESEARCH_PLAN.md): на обычном молоте частичный игровой PASS для hide после ~2016 мс, раннего release, отмены pending hide и ручного STOP с собственной маской. Одного `hilda_cudgel_sheath` визуально недостаточно. Обычные InHand-атаки и опасный overlap позднего Sheath post не получили полного игрового acceptance.
- [Visual isolation A/B](https://github.com/NikichMods/MagicalScabbards/blob/9fc109cac79895e1ed0cd5fae0e2d71f79c2e49d/docs/SCABBARD_VISUAL_ISOLATION_AB_09.md): **PASS в игре** для поочерёдного hide/show `hilda_BP_C.scabbard_a/b`. A скрывает длинный диагональный корпус и кольцо, B — маленькую накладку; `hilda_cudgel_sheath` отдельно скрывает нижний выступ.
- [Combined visibility 10](https://github.com/NikichMods/MagicalScabbards/blob/a8a76622888d0257e08e8442ffd80cdd5d93453b/docs/SCABBARD_COMBINED_VISIBILITY_10.md): **PASS в игре** для совместного скрытия `hilda_cudgel_sheath + scabbard_a + scabbard_b` и ручного восстановления B → A → sheath с `CLEANED owned=false`. Убранный held mesh оставался скрыт. На пояснице остались светящийся медальон и тёмные детали; их owner неизвестен. Сеанс **не проверял** поведение маски при draw/stow.

## Открытые блокеры

**State Reconcile 01:** read-only сеанс на шести типах завершён. Десять модельных допусков через 3018–3033 мс, смены, reload и STOP наблюдались. [Игровое свидетельство](SCABBARD_STATE_RECONCILE_01.md#игровой-сеанс-2026-11-09).

**Boundary 01:** read-only игра подтвердила BLOCKED на видимом старом молоте вне native slots, затем CLEAR после его ухода. Два обычных draw на видео подтверждают пригодность generic pre для узкого маршрута с оговоркой о точности кадров. Следующий барьер — владение и откат нового write-контроллера. [Игровой результат](SCABBARD_RECONCILE_BOUNDARY_02.md#игровой-сеанс-boundary-01).

**Write 01:** Lua 5.4 PASS и пять игровых скрытий шести деталей. Приёмка FAIL: видимое появление в stowed и неподтверждённая очистка двух целей при смене, STOP с долгом. [Игровой результат](SCABBARD_RECONCILE_WRITE_01.md#игровой-сеанс-2026-11-10).

1. **Визуальный состав:** совместное скрытие шести целей подтверждено для проверенного набора. Покрытие других конфигураций остаётся открытым.
2. **Динамика/владение:** подтверждение раннего draw для поддерживаемых маршрутов, корректная обработка перекрывающихся skill/Sheath, вмешательства штатных writers, инвалидации трёхсекундного окна и rollback только собственной записи, в том числе при lifecycle/reload. Изолированный ручной PASS не закрывает эти gates.
3. **Поддерживаемый объём:** другие виды оружия, совместимость с CombatHUD/HildaSoftLight/косметическими модами и VFX проверяются после безопасного механизма для базового семейства.

## Исторические результаты кандидатов

[scabbard-asset-census-01](SCABBARD_ASSET_CENSUS_11.md#игровой-результат-2026-11-07) — **PASS** для read-only снимка обычного молота. Помимо трёх контролей найдены три прикреплённых кандидата: spear unuse, staff sheath и dual unuse. Соответствие остаточной геометрии и production остаются **BLOCKED**.

[scabbard-residual-isolation-01](SCABBARD_RESIDUAL_ISOLATION_12.md#повторный-сеанс--pass-для-поочерёдной-изоляции) — **PASS** для трёх одиночных изоляций при скрытой базе и штатного финального восстановления. Пользователь подтвердил визуальный вклад всех трёх дополнительных компонентов. Совместное скрытие шести проверено в следующем сеансе ниже.

[scabbard-dynamic-cudgel-01](SCABBARD_DYNAMIC_CUDGEL_13.md#игровой-сеанс-2026-11-07--pass-в-подтверждённом-наборе) — **PASS** для одновременного скрытия и восстановления шести целей, раннего draw, обычных атак в руках, задержки после Sheath, пропуска позднего Sheath и ручного STOP. Production **BLOCKED**. Отмена уже поставленного таймера — игровой PASS 2026-11-08. Повторный Sheath подтверждён в стабе.

[scabbard-freeplay-01](SCABBARD_FREEPLAY_14.md) подтвердил в игре доставку уведомления о смене слота, восстановление диагностики после reload и STOP. Для проверенной смены Blueprint post уже поздний для всей старой группы. Автоматическая запись при свободной игре BLOCKED.

[scabbard-universal-01](SCABBARD_UNIVERSAL_15.md#игровой-сеанс-2026-11-08) подтвердил сохранение шести старых привязок на входе в EndPlay при одной смене оружия. Синхронный release там ещё не проверялся. Принято единое правило PASS-THROUGH / SUPPRESSED для произвольного подмножества каталога. Автоматический write-кандидат ждёт доказательства безопасного release, роли новых экземпляров и владения каналом подавления.

Метод и стоп-условия: [RESEARCH_PLAN.md](RESEARCH_PLAN.md). Исторические test-кандидаты и исходники остаются в `research/*`; не переписывать их frozen SHA. Общие переносимые открытия по Asterigos — в [Asterigos-Research](https://github.com/NikichMods/Asterigos-Research/blob/main/docs/RESEARCH_INDEX.md).

[scabbard-endplay-release-01](SCABBARD_ENDPLAY_RELEASE_16.md#игровой-результат-2026-11-08) — игровой PASS для синхронного снятия двух масок на компонентах Хильды при смене молота на парные клинки. Уходящие компоненты были read-only и ещё разрешались после смены. Автоматическое подавление и production остаются BLOCKED.

[scabbard-equipment-lifetime-01](SCABBARD_EQUIPMENT_LIFETIME_17.md#игровой-сеанс-2026-11-08) подтвердил уничтожение владельцев и замену обоих экземпляров при возврате молота в одном цикле. Старые компоненты ещё разрешались вне комплекта и сохраняли штатные значения флагов в снимках. Ранний release для уходящей экипировки ещё не доказан.

[scabbard-integrated-01](SCABBARD_INTEGRATED_18.md#игровой-сеанс-2026-11-08) подтвердил автоматический hide/show молота, быструю отмену, раздельный учёт RELEASED/RETIRED при двух сменах и чистый STOP. Посох и клинки оставались без своего hide после stow. Reload с этим кандидатом в игре не зафиксирован. Production gate остаётся BLOCKED.

[scabbard-integrated-02](SCABBARD_INTEGRATED_19.md#игровой-сеанс-2026-11-08) подтвердил полный hide/show посоха и отмену таймера. У клинков Sheath и таймер сработали, но осталась видимая деталь. После смены с оружием в руках новый Sheath для hide не подтверждён. STOP чистый, reload не зафиксирован. Полное покрытие и production остаются BLOCKED.

[scabbard-integrated-03](SCABBARD_INTEGRATED_20.md#игровой-сеанс-2026-11-08) подтвердил восстановление hide после первого draw/stow посоха при смене с клинками в руках. Единственная отклонённая цель при hide клинков — `hilda_staff_unuse`. Визуальная роль остатка и допуск к записи ещё открыты.

**[Integrated 04](SCABBARD_INTEGRATED_21.md#игровой-сеанс-2026-11-09), 2026-11-09:** установленный исходник `888e0d9` прошёл один игровой прогон с совпадением SHA-256 и `CLEANED retired=0`. **PASS** полного визуального скрытия и возврата шести целей на проверенных клинках с молотом; шестая — `hilda_staff_unuse`, прежний остаток слева исчез. **Два отдельных FAIL** восстановления при смене оружия: (a) новый menu Sheath пришёл, но двухсекундный expiry наступил на ~0,508 с раньше EndPlay старого drawn-актора, и ожидание было утрачено; (b) реальный ранний skill `hilda_staff_atk1` без `_idle` при переключении молот→посох не был распознан и оставил `drawPending=true`. Это воспроизведённые узкие переходные дефекты, не доказательство некорректного write/rollback. Полное покрытие остальных наборов, pickup, reload и production остаётся **BLOCKED**. Следующий шаг — событийно продолжать matured menu Sheath после EndPlay и точно распознавать дополнительный staff draw, без покадрового скана и без повторного визуального A/B.

[scabbard-integrated-05](SCABBARD_INTEGRATED_22.md#игровой-сеанс-2026-11-09) — игровой PASS переключения молот → посох кнопками и STOP. Клинки → посох через меню без атаки остался FAIL: ожидание пережило дедлайн, но скрытие после следующего EndPlay не выполнено. Production остаётся BLOCKED.

[Integrated 06](SCABBARD_INTEGRATED_23.md#игровой-сеанс-2026-11-09) — игровой PASS для клинки → посох через меню без атаки, молот → посох второй кнопкой и чистого STOP. Штатные getters сработали в проверенном наборе. Обратная смена на клинки с поздним появлением второй руки осталась без автоматического hide. Production остаётся BLOCKED.


[Integrated 07](SCABBARD_INTEGRATED_24.md) — исходник и frozen Integrated 06 прошли свои stubs на Lua 5.4. Sheath main запускает ожидание независимо от второй руки, а запись требует полный подтверждённый native набор и сравнивает его идентичности на протяжении операции. Копьё, меч со щитом и браслеты остаются в PASS-THROUGH с read-only наблюдением draw.

Игровой Integrated 07 подтвердил обе смены через меню и отмену быстрого hide. Комбо-смена молот → посох выявила незарегистрированный `hilda_staff_switch_enter`. [Integrated 08](SCABBARD_INTEGRATED_24.md#integrated-08--адресная-регрессия-комбо-смены) прошёл Lua 5.4 с исправлением точного сигнала. На момент исходного отчёта оставался установлен 07. Отдельный write-прогон 08 уступил место проверке достаточности текущего снимка по новому контракту.

## Репозиторий

[NikichMods/MagicalScabbards](https://github.com/NikichMods/MagicalScabbards); стабильный контракт — `main`, непроверенный runtime — `research/*` / `dev/*`. Первоначальный bootstrap: [6e8062ca](https://github.com/NikichMods/MagicalScabbards/commit/6e8062ca782f2fa72f058a949e7b1e62fc8a052f).
