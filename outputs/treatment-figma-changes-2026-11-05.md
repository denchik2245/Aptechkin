# Изменения макетов «Лечение»

Дата: 5 ноября 2026.

Рабочая секция: [Лечение](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1028-16806).

Первый экран: [Сегодня](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1031-16811).

Исходные 19 макетов сохранены в секции [Архив / Лечение до правок](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=723-3238).

Новая редакция содержит 66 редактируемых экранов и состояний. Использованы существующие компоненты, стили Manrope, системный SF Pro и переменные приложения. Растром осталась только отдельная иллюстрация пустого состояния; интерфейс собран из редактируемых слоёв.

## Выполнено

- Текущий приём поднят над выполненными; принятые свёрнуты. Добавлены отдельные состояния для человека, другого дня, календаря и одновременных приёмов.
- Показаны получатель, время по плану, фактическое время и автор отметки.
- Добавлены отмена отметки, исправление времени без повторного списания, состояние без сети и защита от повторной отметки другим участником.
- Создание курса включает необязательное название, автоматическое имя, черновик, выбор из аптечки, ручное добавление и проверку итоговой схемы.
- Показаны разные сроки препаратов, ежедневная схема, дни недели, циклы, через день, разные дозы по времени и приём по необходимости.
- Добавлены пауза, возобновление, изменение курса с выбранной даты и создание нового черновика на основе завершённого.
- В сценариях запаса показаны конкретные упаковки, просроченная упаковка, неизвестный остаток, разные единицы, ручная сверка и общий расход нескольких курсов.
- Причина пропуска необязательна и не выбрана заранее. Изменение назначения ведёт к редактированию курса.
- Напоминания включают системное разрешение, пробную отправку, ограниченные повторы и приватность на блокировке.
- Семейный доступ разделяет просмотр, отметки, вложения и причины пропусков. У сообщения близкому есть получатель и условие отправки.
- Приватное уведомление скрывает препарат и дозу; открытие расписания предшествует отметке.
- Добавлены покупка без дубликата позиции, вложение назначения, загрузка и ошибка загрузки.

## Проверка

- Все 66 корневых экранов существуют, имеют ожидаемые имена и ширину 390.
- Нет перекрытия экранов и выхода за границы секции.
- Проверка не обнаружила переполнения текста по горизонтали и неверных семейств шрифтов.
- Основные переходы связаны в прототипе. Состояния внешних событий, например отсутствия сети, представлены отдельными макетами.
- Визуально проверены общая композиция и ключевые экраны; исправлены заголовки, переносы, ширина статусов, подписи дозы и приватное уведомление.

Логика списания, синхронизации, уведомлений и расчёта запаса описана состояниями интерфейса. Изменения относятся к макетам Figma; примеры значений являются демонстрационными.

## Уточнение визуальной иерархии и контролов

По обратной связи исправлены 69 групп заголовков, 114 кнопок и 127 чипов на всех 66 новых макетах. Отступ перед заголовком раздела — 24 px, до его содержимого — 8 px, между элементами списка — 12 px. Для обычных кнопок восстановлены исходные компоненты с высотой 60 px: синяя основная и серая второстепенная, без добавленных контурных вариантов. Группы кнопок используют исходный шаг 8 px. У чипов без иконок симметричные горизонтальные отступы 16 px и центрирование текста. Числовая проверка центровки и сравнение кнопок с исходными компонентами прошли без отклонений.

## Экраны

- [Лечение / Сегодня](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1031-16811)
- [Лечение / Сегодня — нет отметки](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1031-16955)
- [Лечение / Сегодня — всё отмечено](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1031-17112)
- [Лечение / Курсы](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1031-17224)
- [Лечение / Первый курс](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1031-17370)
- [Лечение / Завершённые курсы](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1031-17437)
- [Лечение / Сегодня — мама](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1031-17509)
- [Лечение / Другой день — без приёмов](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1031-17620)
- [Лечение / Календарь](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1031-17723)
- [Курс / Простуда — активный](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1032-17522)
- [Курс / История приёмов](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1032-17636)
- [Курс / Простуда — завершён](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1032-17762)
- [Курс / На паузе](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1032-17844)
- [Курс / Изменение с выбранной даты](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1032-17923)
- [Курс / Проверка изменений](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1032-17999)
- [Курс / Приостановить](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1032-18044)
- [Курс / Возобновление](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1032-18136)
- [Курс / Создать на основе завершённого](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1032-18199)
- [Новый курс / Шаг 1 — Основное](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1033-18094)
- [Новый курс / Шаг 2 — Препараты](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1033-18199)
- [Новый курс / Шаг 3 — Проверка](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1033-18254)
- [Новый курс / Выбор препарата](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1033-18338)
- [Новый курс / Поиск — ничего не найдено](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1033-18423)
- [Новый курс / Препарат вручную](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1033-18468)
- [Лечение / Сохранённый черновик](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1033-18527)
- [Новый курс / Разные сроки препаратов](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1033-18603)
- [Схема / Каждый день](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1036-18763)
- [Схема / По дням недели](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1036-18909)
- [Схема / Циклами](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1036-19050)
- [Схема / Через день](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1036-19169)
- [Схема / Доза зависит от времени](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1036-19279)
- [Схема / По необходимости](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1036-19350)
- [Курс / Перерыв между циклами](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1036-19414)
- [Напоминания / Смена часового пояса](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1036-19492)
- [Приём / Отложить](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1037-19072)
- [Приём / Пропустить](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1037-19190)
- [Приём / Отметить задним числом](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1037-19283)
- [Приём / Исправить существующую отметку](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1037-19409)
- [Приём / Сохранено — отмена](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1037-19520)
- [Приём / Пропуск сохранён](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1037-19639)
- [Приём / Необязательная причина](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1037-19749)
- [Приём / Отметка отменена](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1037-19865)
- [Приём / Уже отмечено другим человеком](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1037-19983)
- [Приём / Без сети](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1037-20081)
- [Приём / Отложено](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1037-20190)
- [Приём / Отложить — пересечение](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1037-20301)
- [Напоминания / Настройки](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1038-19956)
- [Напоминания / Нет разрешения](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1038-20053)
- [Напоминания / Разрешены — проверка](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1038-20096)
- [Доступ / Личный курс](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1038-20139)
- [Доступ / Права и сообщение близкому](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1038-20187)
- [Доступ / Близкий добавлен](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1038-20268)
- [Напоминания / Приватность на блокировке](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1038-20315)
- [Уведомление / Название, доза и действия](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1038-20366)
- [Уведомление / Без личных подробностей](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1038-20414)
- [Запас / Выбор конкретной упаковки](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1039-20328)
- [Запас / Остаток неизвестен](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1039-20409)
- [Запас / Капли и миллилитры](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1039-20452)
- [Запас / Сверить таблетки](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1039-20507)
- [Запас / Сверить миллилитры](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1039-20560)
- [Запас / Одна упаковка — несколько курсов](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1039-20607)
- [Запас / Добавлено в покупки](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1039-20656)
- [Назначение / Прикреплённое фото](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1039-20698)
- [Назначение / Загрузка фото](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1039-20737)
- [Назначение / Ошибка загрузки](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1039-20781)
- [Лечение / Несколько приёмов одновременно](https://www.figma.com/design/tAZysbFzUOJg6xv4iN6YU7/?node-id=1042-20713)

