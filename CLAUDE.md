# Аптечкин — заметки для работы над проектом

Flutter-приложение для учёта домашних лекарств. Основная платформа — **Android**, на **iPhone открывается web-версия** (Flutter Web). Язык интерфейса и общения — русский.

Текущая задача: **навести порядок и довести до конца исследование (Google Таблица), макеты (Figma) и код**, код — переносом макетов из Figma в точности, раздел за разделом. Перед переносом проведён рефакторинг (дизайн-система, маршруты, чистые операции над состоянием).

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

- Рабочая ветка: `main` (содержимое `refactor/figma-port` перенесено в неё 2026-11-23, другие ветки удалены). Ничего не коммитим без просьбы.
- UX-исследование (аудитория, интервью, гипотезы) — в [Google Таблице](https://docs.google.com/spreadsheets/d/1og3PHNSFE21zZF7H7mJC8ODTAqofRC9tDWoLGc3ctyc/edit?usp=sharing), а не в репозитории.
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
7. Обновить `docs/design-system.md` (раздел про перенесённый экран) и [`docs/progress/code.md`](docs/progress/code.md).

## Прогресс

Где мы остановились — в [`docs/progress/`](docs/progress/README.md). **В начале сессии прочитать `docs/progress/README.md`**, в конце — обновить «Где остановились» и журнал.

- [research.md](docs/progress/research.md) — Google Таблица с исследованиями.
- [figma.md](docs/progress/figma.md) — макеты в Figma и чего в них не хватает.
- [code.md](docs/progress/code.md) — перенесённые разделы, следующий шаг, отложенное и отличия кода от макета.
