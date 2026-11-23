# Аптечка — заметки для работы над проектом

Flutter-приложение для учёта домашних лекарств. Основная платформа — **Android**, на **iPhone открывается web-версия** (Flutter Web). Язык интерфейса и общения — русский.

Текущая задача: **перенести макеты из Figma в точности, раздел за разделом**. Перед переносом проведён рефакторинг (дизайн-система, маршруты, чистые операции над состоянием).

## Команды

Flutter SDK лежит в `.tooling/flutter` (не в Git, не в PATH):

```bash
./.tooling/flutter/bin/flutter analyze
./.tooling/flutter/bin/flutter test
./.tooling/flutter/bin/flutter build web --release
```

Просмотр web-сборки: `.claude/launch.json` → конфигурация `web-release` (`node tools/serve_web.js`, порт 5180). После пересборки в браузере сбрасывать service worker и кэш, иначе показывается старая версия:

```js
for (const r of await navigator.serviceWorker.getRegistrations()) await r.unregister();
for (const k of await caches.keys()) await caches.delete(k);
location.reload();
```

Чтобы пропустить онбординг в браузере: `localStorage.setItem('flutter.aptechka_onboarding_completed_v1','true')`.
Если панель браузера скрыта, страница рисуется с задержкой, и скриншоты бывают устаревшими. В панели нет камеры, поэтому сканер там всегда показывает ошибку камеры.

## Git

- Рабочая ветка: `refactor/figma-port` (от `main`). Ничего не коммитим без просьбы.
- Резервная копия старого локального состояния: ветка `backup/local-before-pull-2026-11-17`.
- `core.autocrlf=true`, и в индексе часть файлов хранится с CRLF, часть с LF. **Не перезаписывать окончания строк массово**: если правите файл скриптом, сохраняйте его исходные окончания. Иначе `git status` показывает десятки «изменённых» файлов. Лечится `git checkout -- <файл>` для файлов без реальных правок.
- В bash-однострочниках с `node -e` не писать `${...}` и `$var` внутри строк: bash подставит переменные. Скрипт кладите в файл через heredoc с `<<'EOF'`.

## Архитектура и правила кода

```text
lib/
  app/            router.dart (GoRouter), routes.dart (все пути — только через AppRoutes)
  core/design/    токены Figma: AppPalette (context.palette), AppTypography, AppRadius, AppSpacing
  core/ui/        компоненты Figma (см. ниже) — экраны собираются из них
  core/theme/     ThemeData поверх токенов
  core/widgets/   DesignIcon (SVG из assets/icons/figma), RoundIconButton (стеклянная 44)
  features/<feature>/{domain,data,application,presentation}
```

- **Цвета** только из `context.palette` (светлая и тёмная тема уже заданы). Никаких `Color(0x…)` и проверок `Brightness.dark` в экранах.
- **Текст** только `AppTypography.<стиль>.copyWith(color: palette.…)`. Стили названы как в Figma: h1, h1Tight, h2, h3, headline, bodyLarge, bodyMedium, paragraph, bodySmall, labelLarge, labelMedium, caption, button, buttonSmall. «Line height 100» в Figma = естественная высота строки (height не задаём).
- **Навигация** через `AppRoutes` (`context.push(AppRoutes.medicine(id))`), без строковых путей.
- **Логика состояния** — чистые функции/extension в `domain` (пример: `kit_operations.dart`, `package_status.dart`, `scanner/domain/scanned_code.dart`). `AppController` только вызывает их и сохраняет результат через `_commit`. Новую логику покрываем unit-тестами без Riverpod.
- **Разрушительные действия** возвращают снимок состояния (`deletePharmacy`, `removePackage`) → тост с «Отменить» вызывает `restoreSnapshot`.
- Данные меняются → `touchKit(kitId, now)`, чтобы обновлялось «Проверено …».
- **Тексты для чисел** склоняются по-русски (`russianCount`, `amountLabel`, `checkedAgoLabel`).
- **Доступность**: у кнопок-иконок `Semantics`/tooltip, крупный шрифт не должен ломать вёрстку (тесты гоняют textScale 1.3 и узкий экран 320).
- Устройство-зависимые флаги (онбординг, запрос уведомлений, пояснение камеры) — в `OnboardingStore`, а не в `AppState`. В тестах `OnboardingStore.load()` не вызывается, поэтому онбординг не мешает.

### Компоненты `core/ui` (соответствие Figma)

| Figma | Код |
|---|---|
| btn (primary/secondary/destructive, с иконкой) | `AppButton`, `AppButton.secondary`, `AppButton.destructive` |
| text btn | `AppTextButton` |
| пустое состояние списка курсов (кружок или картинка, заголовок 22, кнопки) | `StateCard` (`core/ui/state_card.dart`) |
| sheet + sheet header | `showAppSheet(context:, title:, builder:)`, `SheetHeader` |
| алерт удаления | `showAppAlert` |
| toast | `showAppToast(context, text, actionLabel:, onAction:)` |
| radio card (+ badge, footer, choice) | `RadioCard`, `ChoiceRow` |
| action row в группе | `ActionGroup` + `ActionRow` |
| chip | `AppChip` (`tintIcon` для одноцветных иконок) |
| search field | `AppSearchField` |
| синяя текстовая ссылка («Нет в справочнике? Заполнить вручную») | `AppLinkButton` |
| catalog item (list) | `features/inventory/presentation/widgets/catalog_item.dart` (`CatalogListItem`) |
| status banner (warning/fail/info/ok) | `StatusBanner` |
| settings row / settings divider / группа, секция настроек | `SettingsRow`, `SettingsGroup` (`.icons`), `SettingsSection`, `SettingsCard`, `SettingsIconTile` (`core/ui/settings_list.dart`) |
| field (empty / filled / error) | `AppField` (`placeholderWhenEmpty`, `required`, `error`) |
| Expiration date | `ExpirySummary` |
| pagination | `PageDots` |
| swipe action + свайп | `SwipeActionButton`, `SwipeReveal` |
| nav bar / title, nav bar / modal, nav bar / card | `TitleNavBar`, `TitleNavBar.modal`, `TitleNavBar.card` |
| Arrow | `ChevronArrow` |
| пустое состояние с картинкой | `EmptyStateCard` |
| select | `AppSelect` |
| segmented | `AppSegmented` |
| switch row | `SwitchRow` |
| stock control (count / level / off) | `StockCounter`, `StockLevelBar`, `StockOffCard` |
| how to use / заметка, specs | `InfoCard`, `SpecsCard` |
| section формы, подпись/ошибка под полем | `FormSection`, `FieldCaption` |
| catalog item (form) | `features/inventory/presentation/widgets/catalog_item.dart` (`CatalogItemCard`) |
| medicine card | `features/inventory/presentation/widgets/package_card.dart` (`PackageCard`, `PackagePhoto`, `PackagePhoto.gtin`) |
| kit card | `features/home/presentation/widgets/kit_card.dart` |
| pack hero, pack facts, opened block | `features/inventory/presentation/widgets/package_hero.dart` (`PackageHero`, `PackageFacts`, `OpenedBlock`) |

Новый повторяющийся элемент из Figma сначала добавляем в `core/ui`, потом используем.

## Как переносить раздел из Figma

Файл: `tAZysbFzUOJg6xv4iN6YU7`, страница «Дизайн» `671:828`. Полная выгрузка структуры страницы большая, поэтому обходим её скриптом (`get_metadata` → JSON → node).

1. `create_session` (fileKey), загрузить навык `skill://figma/figma-design-to-code/SKILL.md`.
2. Перечислить кадры раздела по metadata. `get_design_context` вызывать на **подузлах** (sheet, body, card), а не на целом кадре, чтобы не тянуть статус-бар и таб-бар каждый раз.
3. Ассеты скачивать сразу (`curl -sSfL`, ссылки живут 7 дней) в `assets/icons/figma/…` или `assets/illustrations/…`. **Новую папку обязательно добавить в `pubspec.yaml`**, иначе иконки молча не отображаются.
4. SVG, выгруженные через `download_assets` с `defaultFormat: svg`, содержат фон секции: серый `rect #B9B9B9` и пути, начинающиеся с `M-`. Их нужно вычистить (так сделано для `form/` и `purpose/`).
5. «illustration placeholder» в Figma — не картинка. Подставляем ближайшую существующую иллюстрацию и сообщаем об этом пользователю.
6. Проверка: `analyze`, `test`, затем web-сборка 390×844 и сравнение со скриншотом Figma.
7. Обновить `docs/design-system.md` (раздел про перенесённый экран) и таблицу прогресса ниже.

## Прогресс переноса

Готово:

| Раздел | Узел | Где в коде |
|---|---|---|
| Онбординг (3 экрана + запрос уведомлений) | 671:874 | `features/onboarding/` |
| Аптечка · 1 · Мои аптечки | 825:4877 | `features/home/presentation/` |
| Аптечка · 2 · Содержимое аптечки | 825:4878 | `features/inventory/presentation/pharmacy_inventory_screen.dart`, `inventory_sheets.dart`, `places_screen.dart` |
| Добавление · 1 · Вход и сканирование | 890:15546 | `features/scanner/` |
| Добавление · 2 · Форма упаковки | 890:15547 | `features/inventory/presentation/add_medicine_screen.dart`, `add_medicine_sheets.dart`, `widgets/catalog_item.dart`, `domain/package_form.dart` |
| Добавление · 3 · Несколько упаковок подряд | 890:15548 | `features/scanner/presentation/barcode_scanner_screen.dart` (`batch`), `quick_add_card.dart`, `add_summary_screen.dart`, `scanner/application/add_batch.dart`, `inventory/domain/quick_add.dart` |
| Добавление · 4 · Поиск по названию | 890:15549 | `features/inventory/presentation/drug_catalog_screen.dart`, `drug_catalog_variants_screen.dart`, `drug_name_field.dart`, `domain/drug_catalog_search.dart`, `data/recent_drug_searches.dart`, `core/ui/search_field.dart` |
| Аптечка · 3 · Фильтры | 825:4879 | `pharmacy_inventory_screen.dart` (`_filterBlocks`), `matchesInventoryFilter` и `removePackages` в `domain/kit_operations.dart`, `AppButton.secondaryDestructive`, `EmptyStateCard` без текста и кнопки, картинки `assets/illustrations/filters/` |
| Карточка лекарства · 1 · Статусы срока | 875:12466 | `features/inventory/presentation/package_detail_screen.dart`, `widgets/package_hero.dart`, `domain/package_detail.dart` |
| Карточка лекарства · 2 · Формы лекарств | 875:12467 | там же (остаток count/level/off, «Вскрыть», «Заметка», «Хранить в холодильнике») |
| Карточка лекарства · 3 · Вскрытие | 875:12468 | там же (`OpenedBlock` в `widgets/package_hero.dart`, `openedSummary`/`timeAgo` в `domain/package_detail.dart`) |
| Карточка лекарства · 4 · Упаковки, курс и справка | 875:12469 | там же (`packageCourse`, `packagesTotal`, `intakeDeductsStock` в `domain/package_detail.dart`; фото во весь экран — `widgets/package_photo_viewer.dart`) |
| Аптечка · 4 · Поиск по всем аптечкам | 825:4881 | `features/inventory/presentation/kit_search_screen.dart`, `domain/kit_search.dart`, `data/recent_searches.dart` (`RecentSearches.kits`), `AppNavigationBar(searchSelected:)`, иконки `assets/icons/figma/symptom/` |
| Аптечка · 5 · Состояние аптечки | 863:12157 | `features/inventory/presentation/kit_state_screen.dart`, `widgets/category_row.dart`, `domain/kit_state.dart`; пункт меню аптечки и действие плашки «Осталось …» в карточке |
| Добавление · 5 · Выбор значений и выход | 890:15550 | `add_medicine_sheets.dart`, `core/ui/radio_row.dart`, `showAppSheet(subtitle:)`; правка упаковки — `AddMedicineScreen(editId:)` (`/medicine/:id/edit`), `AppController.replacePackage`; «Для чего» — `Medicine.purposes` + `customPurpose` |
| Настройки · 1, 2, 3, 5 (без облака) | 1194:16667, 1194:16668, 1194:16669, 1194:16671 | `features/settings/presentation/` (`settings_screen.dart`, `appearance_screen.dart`, `notification_settings_screen.dart`, `thresholds_screen.dart`, `backup_screens.dart`, `help_screen.dart`, `about_screen.dart`), `core/ui/settings_list.dart`, `settings/domain/settings_summary.dart`, `settings/data/backup_files.dart` (`share_plus`, `file_selector`, `BackupStore`), иконки `assets/icons/figma/settings/` |
| Лечение · 1 · Сегодня | 1186:21990 | `features/reminders/presentation/reminders_screen.dart` (вкладка «Сегодня», шторка «Выбор человека»), `widgets/today_widgets.dart` (`PersonSwitcher`, `DayCell`, `PlannedIntake`, `IntakeRow`, `IntakeNowCard`, `TreatmentDoneCard`), `domain/treatment_today.dart` |
| Лечение · 2 · Отметки приёма | 1186:21991 | `features/reminders/presentation/intake_actions.dart` (шторки, `IntakeOutcome`), сообщения в `reminders_screen.dart` (`_message`), `domain/intake_marks.dart`, `AppController.undoIntake`, `AppSelect(small:)`, `AppLinkButton(small:)` |
| Лечение · 3 · Список курсов | 1186:21992 | вкладка «Курсы» в `reminders_screen.dart` (`_courseList`), `widgets/course_card.dart` (`CourseCard`, `FirstCourseImage`), `domain/course_list.dart`, `core/ui/state_card.dart` (`StateCard`), картинка `assets/illustrations/treatment/` |
| Карточка лекарства · 5 · Действия | 875:12470 | `package_action_sheets.dart` (уровень, вскрытие, «Убрать …?»), `inventory_sheets.dart` (`showStockSheet`/`showMoveSheet` с `fromCard`), `packagePieces`/`RemovalReason` в `domain/package_detail.dart` |

**Следующий шаг: Аптечка · Позже · Ревизия (825:4880)** — «Проверить аптечку» в меню и на баннере. Разделы «Добавление», «Аптечка» 1–5, «Настройки» (без облака) и «Лечение» 1–3 перенесены. Быстрая карточка пакетного сканера проверена тестами, но не глазами (в панели нет камеры).

Осталось (в порядке Figma):

- Аптечка: Позже · Ревизия (825:4880), Позже · Общий доступ (825:4882).
- Лечение: 1186:21993 … 1186:21997 (карточка курса, создание, схемы, запас, напоминания). «1 · Сегодня», «2 · Отметки приёма» и «3 · Список курсов» перенесены; карточка курса, редактор курса и предпросмотр уведомления пока в прежней вёрстке.
- Настройки · 4 · Аккаунт (1194:16670) и облачные части разделов 1 и 3 — ждут настоящего облака (решение пользователя 2026-11-18).
- Общие компоненты: секция «Компоненты» 677:917, локальные компоненты настроек 1154:23704 и лечения 1028:16807.

## Отложенное и открытые вопросы

- В меню аптечки нет пунктов «Проверить аптечку» и «Общий доступ». Добавить вместе с их разделами. Действие «Проверить аптечку» на баннере тоже ждёт раздела «Ревизия».
- При первом запуске в «Доме» лежат демо-лекарства, а по макету после онбординга список пустой. Спросить пользователя, нужны ли демо-данные.
- «Включить уведомления» включает только напоминания внутри приложения: системные уведомления не подключены.
- «Открыть настройки» на экране «Нет доступа к камере» пока повторно запрашивает доступ. Для настоящего перехода в настройки нужен пакет (например, `permission_handler`). Новые зависимости добавлять только с согласия пользователя.
- «Выбрать из галереи» скрыта на web: `analyzeImage` там не поддерживается.
- «Для чего» (890:15550): список назначений и «Свой вариант». «Боль в ухе» и «Раны» есть в «Состоянии аптечки», но не в шторке макета — оставлены в шторке после «Аллергии»; спросить пользователя, если нужно ровно как в макете. Поиск по «Своему варианту» не ищет. Иконки чипов назначений — из шторки «Для чего» (`assets/icons/figma/symptom/`); у «Давления», «Витаминов», «Другого» и «Своего варианта» на карточке значок «?». Подпись правки «Температура — из справочника» из макета не показана: назначений в справочнике нет. В «Состоянии аптечки» категории «Горло» и «Живот» — свои (в макете шесть строк), плашки категории кроме «Осталось мало» — тоже свои. Группа «Срок не указан» в поиске по симптому — своя (в макете её нет). Строка статуса «Срок истёк в августе» из макета не совпадает с карточкой («Срок истёк N дней назад»): карточка общая, оставлена как в разделе «Содержимое аптечки».
- Иконки аптечек — SVG из Figma. В описании компонента сказано «системные иконки (Material на Android)»; выбрана точность макета.
- Упаковка хранит `stockLevel` (остаток по уровню), `tracksStock` (приборы) и `noExpiry` («Без срока годности»). Карточка лекарства и экран деталей показывают их через `amountLabel` и `packageStatusLine`; подробно — при переносе «Карточки лекарства».
- «Фото упаковки» в форме: своё фото добавить нельзя, нужен пакет выбора изображений (например, `image_picker`) — только с согласия пользователя.
- Карточка лекарства: у `Medicine` появились `description`, `usage`, `storage` (заполнить неоткуда, блоки скрыты без данных) и `addedAt`/`updatedAt`/`stockUpdatedAt` (ставятся при добавлении и правках через `editPackage`; у старых упаковок дат нет, строка «Добавлено …» скрыта). «Полная инструкция» не показана: нужен пакет открытия ссылок (например, `url_launcher`) — только с согласия пользователя. Экран «Справка / Полная инструкция» (879:14684: показания, способ применения, противопоказания, побочные действия, хранение, «Из справочника ГРЛС» и «Открыть на сайте») не сделан: этих сведений в данных нет, а выдумывать их нельзя; нужен источник ГРЛС и `url_launcher`. «Сфотографировать вкладыш», «Заменить фото» и «Удалить фото» ждут пакета выбора изображений. Причина в шторке «Убрать …?» (875:12470) пока не сохраняется: в модели нет истории удалений и списка «чего не хватает». В карточке «Инструкции нет в справочнике» текст сокращён до «Добавьте заметку — например, как принимать.», пока сфотографировать вкладыш нельзя. «Вскрыть» с ответом «Не знаю» отмечает вскрытие без срока: карточка просит «Указать срок» (так в 875:12468), а в списке аптечки упаковка попадает в «Срок не указан».
- Настройки: облака нет, поэтому нет строки «Сохранять в облаке», варианта главной «с аккаунтом» (1155:23941), карточки «В облаке» и всего подраздела «4 · Аккаунт». Старый демо-аккаунт (`/account`, `features/accounts/`) из настроек больше не открывается, но код и маршрут остались; если на устройстве был вход в демо-профиль, выйти из него теперь негде. Из прежних настроек убраны (в макете их нет) «Аптечка при запуске», «Сортировка препаратов», переключатели «Сроки годности»/«Малый остаток», «Сбросить настройки» и «Удалить все записи»; поля в `AppSettings` остались со своими значениями. Сводка по аптечкам и «Приём лекарств» только сохраняют выбор: системных уведомлений нет, поэтому вариант «Уведомления запрещены в iPhone» (1157:24166) не сделан, а в «Данные восстановлены» строка «Уведомления» подписана «Приём лекарств и сводка» вместо «Разрешение нужно дать заново». «Раз в месяц» — 1-го числа (в макете нет выбора дня месяца). Пример пуша «Так выглядит сводка» — статичный текст из макета. «Политика конфиденциальности» и «Пользовательское соглашение» скрыты: текстов нет; «Ваши данные» в «О приложении» переписан под хранение только на телефоне. Ответы «Помощи» в макете не нарисованы — свои, в шторке. На Android «Копия сохранена» показывается, когда в меню «Поделиться» выбрали приложение, — сохранил ли его человек, система не сообщает. Шрифт Manrope в проекте примерно на 5 % шире, чем в Figma, поэтому, например, «Срок — за 30 дней · остаток — 2 ед.» на главной переносится на вторую строку.
- Лечение · Сегодня (1186:21990): в макете на экране нет плашек «Расписание на паузе», «Предупреждения выключены», кнопки «Список покупок» и календаря по нажатию на дату — оставлены из прежней версии. Строка «Следующий — …» в «Все приёмы отмечены» показывается только для сегодняшнего дня. Цвета статусов «Пропущено» (оранжевый) и «Отложено до …» (синий) в этом разделе макета не нарисованы — выбраны свои. `IntakeRow` теперь общий с историей курса (вёрстка истории сменится вместе с разделом «Карточка курса»).
- Лечение · Отметки (1186:21991): не сделаны «Уже отмечено другим человеком» (нужен общий доступ) и «Без сети» (нужно облако). «Причину можно добавить позже» в «Пропустить приём?» — подпись, не ссылка. После «Сохранить время» в «Исправить отметку» показывается сообщение «Приём отмечен в …» (в макете после правки времени сообщения нет). Сообщение живёт, пока не сменили день или не сделали новое действие. Нажатие на пропущенную строку открывает «Когда приняли?» (в макете не нарисовано). «Проверьте время» срабатывает, только если новое время дошло до следующей дозы того же лекарства у того же человека.
- Лечение · Список курсов (1186:21992): не сделаны «Загрузка», «Ошибка загрузки» и «Офлайн — сохранённые курсы» — данные локальные. Когда нет ни курсов, ни напоминаний, «Добавьте первый курс» показывается на обеих вкладках (в макете — на «Курсах»). Склонение названий («Ибупрофена», «Миши») — по правилу для первого слова; несклоняемые и латинские названия остаются как есть. «Запас не рассчитан» — когда единицы дозы и упаковки не совпадают (капли из флакона). Порог «хватит на N дней»: до конца курса, у постоянного — 7 дней.
- Свайп по карточке лекарства и экраны после скана (шторки «уже есть» и «не нашли») проверены тестами, но не глазами: в панели браузера нет камеры.
