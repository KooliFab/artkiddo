import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Which of `drawnAt`/`addedAt` was used as the reference date for an
/// [Formatters.age] result — the interface always says which of the
/// two it uses, never confusing them. The screen uses this to pick
/// the matching label instead of guessing.
enum AgeBasis { drawnAt, addedAt }

/// Single shared date/age formatting utility.
///
/// Dates are always formatted with the Canadian locale variants
/// (`fr_CA` / `en_CA`) explicitly, independent of the ARB catalog's
/// own (language-level) locale. The age labels are fixed in the
/// catalogs and are never recomposed here.
class Formatters {
  const Formatters._();

  static String _icuLocale(AppLocalizations l10n) =>
      l10n.localeName.startsWith('fr') ? 'fr_CA' : 'en_CA';

  /// `d MMMM y` in FR-CA, `MMMM d, y` in EN-CA — e.g. "3 septembre
  /// 2026" / "September 3, 2026".
  static String date(AppLocalizations l10n, DateTime date) {
    final locale = _icuLocale(l10n);
    final pattern = locale == 'fr_CA' ? 'd MMMM y' : 'MMMM d, y';
    return DateFormat(pattern, locale).format(date);
  }

  static String dateShort(AppLocalizations l10n, DateTime date) {
    final locale = _icuLocale(l10n);
    final pattern = locale == 'fr_CA' ? 'd MMM y' : 'MMM d, y';
    return DateFormat(pattern, locale).format(date);
  }

  /// Date + time, for the last-backup summary ("Last backup: `date/time`").
  static String dateTime(AppLocalizations l10n, DateTime dateTime) {
    final locale = _icuLocale(l10n);
    return '${date(l10n, dateTime)} ${DateFormat.jm(locale).format(dateTime)}';
  }

  /// Age display rule, computed on `drawnAt` when present, on
  /// `addedAt` only as a fallback. Use [ageBasis] to know which one a
  /// given call used, so the caller can label the figure correctly:
  /// - reference before birthDate -> `age.beforeBirth`
  /// - < 1 month -> `age.lessThanMonth`
  /// - < 24 months -> `age.months`
  /// - months == 0 -> `age.years`
  /// - else -> `age.yearsMonths`
  static String age(
    AppLocalizations l10n, {
    required DateTime birthDate,
    required DateTime addedAt,
    DateTime? drawnAt,
  }) {
    final reference = drawnAt ?? addedAt;
    if (reference.isBefore(birthDate)) {
      return l10n.ageBeforeBirth;
    }

    int years = reference.year - birthDate.year;
    int months = reference.month - birthDate.month;
    int days = reference.day - birthDate.day;
    if (days < 0) months -= 1;
    if (months < 0) {
      years -= 1;
      months += 12;
    }
    final totalMonths = years * 12 + months;

    if (totalMonths < 1) return l10n.ageLessThanMonth;
    if (totalMonths < 24) return l10n.ageMonths(totalMonths);
    if (months == 0) return l10n.ageYears(years);
    return l10n.ageYearsMonths(years, months);
  }

  /// Which of `drawnAt`/`addedAt` an [age] call with the same
  /// `drawnAt` argument used — a pure function of `drawnAt`'s
  /// presence, so the screen can state which basis it is showing
  /// without guessing.
  static AgeBasis ageBasis({required DateTime? drawnAt}) =>
      drawnAt != null ? AgeBasis.drawnAt : AgeBasis.addedAt;
}
