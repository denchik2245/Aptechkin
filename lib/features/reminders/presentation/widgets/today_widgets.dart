import 'package:aptechka/core/design/design.dart';
import 'package:aptechka/core/ui/app_button.dart';
import 'package:aptechka/core/widgets/design_icon.dart';
import 'package:aptechka/features/reminders/domain/treatment_schedule.dart';
import 'package:aptechka/features/reminders/domain/treatment_today.dart';
import 'package:aptechka/features/reminders/presentation/treatment_widgets.dart';
import 'package:flutter/material.dart';

/// «Выбор человека» in the «Лечение» header (1068:21880): H1 name and a
/// 16 pt chevron, like the kit switcher.
class PersonSwitcher extends StatelessWidget {
  const PersonSwitcher({required this.person, required this.onTap, super.key});
  final String person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: 'Лечение: $person. Выбрать человека',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  person,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.h1.copyWith(color: palette.textHeading),
                ),
              ),
              const SizedBox(width: 4),
              DesignIcon(
                'kit-switcher-chevron',
                size: 16,
                color: palette.textHeading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «day cell» (722:3327): 44 × 68, radius 14. Selected — brand fill and
/// white text; future — the number in `text/secondary`; the dot shows how
/// the intakes went.
class DayCell extends StatelessWidget {
  const DayCell({
    required this.weekday,
    required this.day,
    required this.selected,
    required this.future,
    required this.mark,
    required this.onTap,
    super.key,
  });

  final String weekday;
  final int day;
  final bool selected;
  final bool future;
  final DayMark mark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dot = selected
        ? 'treatment-day-selected'
        : switch (mark) {
            DayMark.done => 'treatment-day-done',
            DayMark.partial => 'treatment-day-partial',
            DayMark.none => null,
          };
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? palette.brandPrimary : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 68),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  weekday,
                  maxLines: 1,
                  style: AppTypography.labelMedium.copyWith(
                    color: selected
                        ? palette.textOnAccent
                        : palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$day',
                  maxLines: 1,
                  style: AppTypography.bodyMedium.copyWith(
                    color: selected
                        ? palette.textOnAccent
                        : future
                        ? palette.textSecondary
                        : palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                if (dot == null)
                  const SizedBox(width: 6, height: 6)
                else
                  DesignIcon(dot, size: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «Время по плану» + «intake row» (722:3272): the planned time in a 44 pt
/// column, then the white row.
class PlannedIntake extends StatelessWidget {
  const PlannedIntake({required this.time, required this.child, super.key});
  final String time;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 44,
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          // One line even with large text on a narrow screen.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              time,
              maxLines: 1,
              style: AppTypography.labelMedium.copyWith(
                color: context.palette.textPrimary,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: child),
    ],
  );
}

/// «intake row» (722:3272): drug, «**Я** · доза · условие», status line and
/// a check, «Отметить» or an empty circle on the right.
class IntakeRow extends StatelessWidget {
  const IntakeRow({
    required this.intake,
    this.onTap,
    this.history = false,
    this.now,
    super.key,
  });

  final TreatmentIntake intake;
  final VoidCallback? onTap;

  /// Course history: the time goes into the details line.
  final bool history;

  /// Defaults to [DateTime.now]; tests pass a fixed time.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final status = intakeStatus(intake, now ?? DateTime.now());
    final details = intakeDetails(intake);
    final secondary = AppTypography.bodySmall.copyWith(
      color: palette.textSecondary,
    );
    final Widget? trailing = switch (status?.tone) {
      IntakeTone.taken => const DesignIcon('status-ok-18', size: 18),
      IntakeTone.missed => Text(
        'Отметить',
        style: AppTypography.bodyMedium.copyWith(color: palette.brandPrimary),
      ),
      IntakeTone.skipped => null,
      IntakeTone.deferred => const DesignIcon('status-warning-18', size: 18),
      null => const DesignIcon('treatment-check', size: 24),
    };
    // A skipped intake is all grey; a deferred one keeps a plain person
    // (1037:19703, 1037:20254).
    final skipped = status?.tone == IntakeTone.skipped;
    final plainPerson = skipped || status?.tone == IntakeTone.deferred;
    return Material(
      color: palette.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicineTitle(intake.medicine),
                      style: AppTypography.bodyMedium.copyWith(
                        color: skipped
                            ? palette.textSecondary
                            : palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          if (history)
                            TextSpan(text: '${intake.reminder.timeLabel} · ')
                          else ...[
                            TextSpan(
                              text: intakePerson(intake),
                              style: plainPerson
                                  ? null
                                  : AppTypography.bodySmall.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: palette.textPrimary,
                                    ),
                            ),
                            if (details.isNotEmpty) const TextSpan(text: ' · '),
                          ],
                          TextSpan(text: details),
                        ],
                      ),
                      style: secondary,
                    ),
                    if (status != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        status.text,
                        // Figma: Label/Medium for «Принято» / «Не отмечено»,
                        // Caption for «Пропущено» and «Отложено до».
                        style: switch (status.tone) {
                          IntakeTone.taken =>
                            AppTypography.labelMedium.copyWith(
                              color: palette.success,
                            ),
                          IntakeTone.missed =>
                            AppTypography.labelMedium.copyWith(
                              color: palette.fail,
                            ),
                          IntakeTone.skipped => AppTypography.caption.copyWith(
                            color: palette.textSecondary,
                          ),
                          IntakeTone.deferred => AppTypography.caption.copyWith(
                            color: palette.warning,
                          ),
                        },
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing],
            ],
          ),
        ),
      ),
    );
  }
}

/// «intake now» (722:3273): the intake that is due now, with «Принял»,
/// «Отложить» and «Пропустить».
class IntakeNowCard extends StatelessWidget {
  const IntakeNowCard({
    required this.intake,
    required this.onTaken,
    required this.onDefer,
    required this.onSkip,
    super.key,
  });

  final TreatmentIntake intake;
  final VoidCallback onTaken;
  final VoidCallback onDefer;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final deferred = intake.record?.deferredUntil;
    final badge = deferred == null
        ? '${intakePerson(intake)} · сейчас'
        : '${intakePerson(intake)} · отложено до '
              '${deferred.hour.toString().padLeft(2, '0')}:'
              '${deferred.minute.toString().padLeft(2, '0')}';
    final details = intakeDetails(intake);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        border: Border.all(color: palette.brandPrimary, width: 2),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: palette.brandPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Text(
                badge,
                style: AppTypography.labelMedium.copyWith(
                  color: palette.brandPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            medicineTitle(intake.medicine),
            style: AppTypography.bodyLarge.copyWith(color: palette.textPrimary),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              details,
              style: AppTypography.bodySmall.copyWith(
                color: palette.textPrimary,
              ),
            ),
          ],
          if (intake.reminder.hint.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              intake.reminder.hint,
              style: AppTypography.bodySmall.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 14),
          AppButton(label: 'Принял', onPressed: onTaken),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final defer = AppButton.secondary(
                label: 'Отложить',
                onPressed: onDefer,
              );
              final skip = AppButton.secondary(
                label: 'Пропустить',
                onPressed: onSkip,
              );
              // Side by side as in Figma; stacked when the labels would not
              // fit (narrow screen or large text).
              if (constraints.maxWidth < 220 ||
                  MediaQuery.textScalerOf(context).scale(16) > 19) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [defer, const SizedBox(height: 8), skip],
                );
              }
              return Row(
                children: [
                  Expanded(child: defer),
                  const SizedBox(width: 8),
                  Expanded(child: skip),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// «Done» (1075:22859): white card, radius 24, 28.8 pt «status / ok».
class TreatmentDoneCard extends StatelessWidget {
  const TreatmentDoneCard({required this.title, this.text, super.key});
  final String title;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          const DesignIcon('status-ok-18', size: 28.8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
                if (text != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    text!,
                    style: AppTypography.bodySmall.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
