import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';

enum AgeBasis { drawnAt, addedAt }

class Formatters {
  const Formatters._();

  static String _icuLocale(AppLocalizations l10n) =>
      l10n.localeName.startsWith('fr') ? 'fr_CA' : 'en_CA';

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

  static String dateTime(AppLocalizations l10n, DateTime dateTime) {
    final locale = _icuLocale(l10n);
    return '${date(l10n, dateTime)} ${DateFormat.jm(locale).format(dateTime)}';
  }

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

  static AgeBasis ageBasis({required DateTime? drawnAt}) =>
      drawnAt != null ? AgeBasis.drawnAt : AgeBasis.addedAt;
}
