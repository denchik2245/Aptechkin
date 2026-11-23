import 'dart:math' as math;

import 'package:aptechka/app/routes.dart';
import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/app_button.dart';
import 'package:aptechka/core/ui/app_segmented.dart';
import 'package:aptechka/core/ui/app_sheet.dart';
import 'package:aptechka/core/ui/radio_card.dart';
import 'package:aptechka/core/ui/state_card.dart';
import 'package:aptechka/core/ui/status_banner.dart';
import 'package:aptechka/core/widgets/async_value_view.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:aptechka/core/widgets/round_icon_button.dart';
import 'package:aptechka/features/inventory/application/medicine_controller.dart';
import 'package:aptechka/features/inventory/domain/app_state.dart';
import 'package:aptechka/features/reminders/domain/intake_marks.dart';
import 'package:aptechka/features/reminders/domain/course_list.dart';
import 'package:aptechka/features/reminders/domain/treatment_course.dart';
import 'package:aptechka/features/reminders/domain/treatment_schedule.dart';
import 'package:aptechka/features/reminders/domain/treatment_today.dart';
import 'package:aptechka/features/reminders/presentation/widgets/course_card.dart';
import 'package:aptechka/features/reminders/presentation/widgets/today_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'treatment_widgets.dart';
import 'intake_actions.dart';
import 'treatment_shopping.dart';

/// «Лечение». The «Сегодня» tab is «1 · Сегодня» (1186:21990); «Курсы» and
/// the empty state are not ported yet.
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});
  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  bool courses = false, showCompleted = false;

  /// The last action on «Сегодня» and its message (1037:19575 …).
  IntakeOutcome? outcome;

  Future<void> _run(Future<IntakeOutcome?> action) async {
    final result = await action;
    if (result != null && mounted) setState(() => outcome = result);
  }

  String person = everyone;
  DateTime date = treatmentDay(DateTime.now());

  Future<void> _pickPerson(AppState state) async {
    final chosen = await showAppSheet<String>(
      context: context,
      title: 'Выбор человека',
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, value) in treatmentPeople(state).indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            RadioCard(
              title: value,
              selected: value == person,
              onTap: () => Navigator.pop(sheetContext, value),
            ),
          ],
        ],
      ),
    );
    if (chosen != null && mounted) setState(() => person = chosen);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.palette.background,
    body: DefaultTextStyle.merge(
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      child: SafeArea(
        bottom: false,
        child: AsyncValueView(
          value: ref.watch(appControllerProvider),
          data: (state) {
            // A person whose courses are gone falls back to «Все».
            if (!treatmentPeople(state).contains(person)) person = everyone;
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.maxContentWidth,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 132),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: PersonSwitcher(
                              person: person,
                              onTap: () => _pickPerson(state),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        RoundIconButton(
                          tooltip: 'Добавить курс',
                          primary: true,
                          icon: const DesignIcon('add-24', size: 24),
                          onPressed: () => context.push(AppRoutes.treatmentNew),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppSegmented(
                      labels: const ['Сегодня', 'Курсы'],
                      selected: courses ? 1 : 0,
                      onChanged: (index) =>
                          setState(() => courses = index == 1),
                    ),
                    const SizedBox(height: 16),
                    // «Курсы / Первый вход» (1113:27415): nothing yet.
                    if (state.courses.isEmpty && state.reminders.isEmpty)
                      _empty()
                    else if (courses)
                      ..._courseList(state)
                    else
                      ..._today(state),
                    if (state.treatmentShoppingIds.isNotEmpty)
                      TextButton(
                        onPressed: () =>
                            showTreatmentShopping(context, ref, const []),
                        child: Text(
                          'Список покупок · ${state.treatmentShoppingIds.length}',
                        ),
                      ),
                    if (!state.settings.expiryAlerts &&
                        !state.settings.stockAlerts)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Text('Предупреждения выключены'),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  /// «Добавьте первый курс» (1113:27538).
  Widget _empty() => StateCard(
    image: const FirstCourseImage(),
    title: 'Добавьте первый курс',
    text:
        'Сохраните схему приёма и настройте напоминания. Лекарства можно '
        'выбрать из аптечки.',
    actions: [
      StateCardAction(
        'Добавить курс',
        () => context.push(AppRoutes.treatmentNew),
      ),
    ],
  );

  /// «3 · Список курсов» (1186:21992): «Текущие» or «Завершённые», grouped
  /// by person for «Все».
  List<Widget> _courseList(AppState state) {
    final palette = context.palette;
    final now = DateTime.now();
    final list = courseList(
      state,
      now,
      person: person,
      completed: showCompleted,
    );
    void addCourse() => context.push(AppRoutes.treatmentNew);
    final Widget body;
    if (!list.isEmpty) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, group) in list.groups.indexed) ...[
            if (i > 0) const SizedBox(height: 20),
            if (group.title.isNotEmpty) ...[
              Semantics(
                header: true,
                child: Text(
                  group.title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            for (final (j, course) in group.courses.indexed) ...[
              if (j > 0) const SizedBox(height: 12),
              CourseCard(
                info: courseCardInfo(state, course, now),
                onTap: () => context.push(AppRoutes.course(course.id)),
              ),
            ],
          ],
        ],
      );
    } else if (showCompleted) {
      final empty = completedEmpty(person);
      body = StateCard(
        title: empty.title,
        text: empty.text,
        actions: [
          StateCardAction(
            'К текущим курсам',
            () => setState(() => showCompleted = false),
            primary: false,
          ),
        ],
      );
    } else if (list.completed == 0 && person != everyone) {
      final empty = personEmpty(person);
      body = StateCard(
        title: empty.title,
        text: empty.text,
        actions: [
          StateCardAction('Добавить курс', addCourse),
          StateCardAction(
            'Показать всех',
            () => setState(() => person = everyone),
            primary: false,
          ),
        ],
      );
    } else {
      body = StateCard(
        title: 'Текущих курсов нет',
        text:
            'Завершённые курсы сохранены в истории. При необходимости можно '
            'добавить новый курс.',
        actions: [
          StateCardAction('Добавить курс', addCourse),
          StateCardAction(
            'Завершённые · ${list.completed}',
            () => setState(() => showCompleted = true),
            primary: false,
          ),
        ],
      );
    }
    return [
      SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: Text(
                showCompleted
                    ? 'Завершённые · ${list.completed}'
                    : 'Текущие · ${list.current}',
                style: AppTypography.bodyMedium.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ),
            AppLinkButton(
              label: showCompleted
                  ? '‹ Текущие'
                  : 'Завершённые · ${list.completed} ›',
              small: true,
              onPressed: () => setState(() => showCompleted = !showCompleted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      body,
    ];
  }

  /// «Сегодня» (1068:21774): week, summary, Утро / День / Вечер.
  List<Widget> _today(AppState state) {
    final palette = context.palette;
    final now = DateTime.now();
    final today = treatmentDay(now);
    final filter = person == everyone ? null : person;
    final slots = TreatmentSchedule.forDay(state, date, person: filter);
    final current = currentIntake(slots, date, now);
    final future = today.isBefore(date);
    final monday = date.subtract(Duration(days: date.weekday - 1));
    void shiftWeek(int days) =>
        setState(() => date = DateTime(date.year, date.month, date.day + days));
    return [
      Semantics(
        label: 'Неделя. Смахните влево или вправо для смены недели',
        onIncrease: () => shiftWeek(7),
        onDecrease: () => shiftWeek(-7),
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity.abs() > 100) shiftWeek(velocity < 0 ? 7 : -7);
          },
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final day = DateTime(
                        monday.year,
                        monday.month,
                        monday.day + i,
                      );
                      return Center(
                        child: SizedBox(
                          width: math.min(44, constraints.maxWidth),
                          child: DayCell(
                            weekday: weekdayShortLabels[i],
                            day: day.day,
                            selected: day == date,
                            future: day.isAfter(today),
                            mark: dayMark(
                              TreatmentSchedule.forDay(
                                state,
                                day,
                                person: filter,
                              ),
                            ),
                            onTap: () => setState(() => date = day),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (!state.settings.intakeSchedule) ...[
        TreatmentBanner(
          'Расписание на паузе',
          'История приёма сохранена',
          action: 'Настроить расписание',
          onAction: () => context.push(AppRoutes.settingsNotifications),
        ),
        const SizedBox(height: 16),
      ],
      if (slots.isNotEmpty && slots.every((s) => s.marked)) ...[
        TreatmentDoneCard(
          title:
              'Все приёмы на ${date == today ? 'сегодня' : 'этот день'} '
              'отмечены',
          text: date == today
              ? nextIntakeLabel(
                  nextIntakeAfter(state, date, person: filter),
                  now,
                )
              : null,
        ),
        const SizedBox(height: 16),
      ],
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () async {
                    final chosen = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(now.year + 10),
                    );
                    if (chosen != null && mounted) {
                      setState(() => date = treatmentDay(chosen));
                    }
                  },
                  child: Text(
                    scheduleDateLabel(date, now),
                    style: AppTypography.bodyLarge.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              takenSummary(slots),
              style: AppTypography.bodySmall.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
      ..._message(slots),
      for (final part in DayPart.values) ...[
        const SizedBox(height: 16),
        _part(
          part,
          [
            for (final s in slots)
              if (DayPart.of(s.reminder.hour) == part) s,
          ],
          current: current,
          future: future,
        ),
      ],
    ];
  }

  /// The message of the last action, with its button and link
  /// (1185:27294, 1185:26806, 1185:26629, 1185:26983).
  List<Widget> _message(List<TreatmentIntake> slots) {
    final o = outcome;
    if (o == null || o.day != date) return const [];
    final s = slots.where((x) => x.reminder.id == o.reminderId).firstOrNull;
    if (s == null) return const [];
    final (title, text) = outcomeMessage(o, s);
    final course = s.course;
    Widget link(String label, VoidCallback onTap) => Align(
      alignment: Alignment.centerLeft,
      child: AppLinkButton(label: label, small: true, onPressed: onTap),
    );
    final undoable =
        o.kind == IntakeOutcomeKind.taken ||
        o.kind == IntakeOutcomeKind.skipped;
    return [
      const SizedBox(height: 16),
      StatusBanner(
        tone: o.kind == IntakeOutcomeKind.taken
            ? StatusBannerTone.ok
            : StatusBannerTone.info,
        title: title,
        text: text,
        actionLabel: undoable ? 'Отменить' : null,
        onAction: undoable ? () => _run(undoMark(context, ref, s)) : null,
      ),
      switch (o.kind) {
        IntakeOutcomeKind.deferred => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            AppButton(
              label: 'Уже принял',
              onPressed: () => _run(markTaken(context, ref, s)),
            ),
            const SizedBox(height: 4),
            link(
              'Изменить время напоминания',
              () => _run(showDeferSheet(context, ref, s)),
            ),
          ],
        ),
        IntakeOutcomeKind.skipped => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            AppButton.secondary(
              label: 'Добавить причину',
              onPressed: () => showReasonSheet(context, ref, s),
            ),
            if (course != null) ...[
              const SizedBox(height: 4),
              link(
                'Врач изменил назначение?',
                () => context.push(AppRoutes.treatmentEdit(course.id)),
              ),
            ],
          ],
        ),
        IntakeOutcomeKind.taken || IntakeOutcomeKind.undone =>
          course == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: link(
                    o.kind == IntakeOutcomeKind.taken
                        ? 'Открыть историю'
                        : 'Посмотреть изменения в истории',
                    () => context.push(AppRoutes.courseHistory(course.id)),
                  ),
                ),
      },
    ];
  }

  /// «Утро» (1068:21802): Body/Medium header, then intakes 12 pt apart or
  /// «Нет запланированных приёмов».
  Widget _part(
    DayPart part,
    List<TreatmentIntake> slots, {
    required TreatmentIntake? current,
    required bool future,
  }) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              part.label,
              style: AppTypography.bodyMedium.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (slots.isEmpty)
            Text(
              'Нет запланированных приёмов',
              style: AppTypography.bodySmall.copyWith(
                color: palette.textSecondary,
              ),
            ),
          for (final (i, s) in slots.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            PlannedIntake(
              time: timeText(s.plannedAt),
              child: s == current
                  ? IntakeNowCard(
                      intake: s,
                      onTaken: () => _run(markTaken(context, ref, s)),
                      onDefer: () => _run(showDeferSheet(context, ref, s)),
                      onSkip: () => _run(showSkipSheet(context, ref, s)),
                    )
                  : IntakeRow(
                      intake: s,
                      onTap: future
                          ? null
                          : () => _run(showIntakeAction(context, ref, s)),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

const weekdayShortLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
