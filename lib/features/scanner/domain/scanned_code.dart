/// What a scan produced: an ordinary barcode (EAN-8/13, GTIN-14) knows only
/// the product; a GS1 DataMatrix code (Russian «Честный знак» marking) can
/// also carry the expiry date, batch and serial number.
enum ScanKind { barcode, dataMatrix }

class ScannedCode {
  const ScannedCode({
    required this.gtin,
    required this.kind,
    this.expiry,
    this.batch,
    this.serial,
  });

  final String gtin;
  final ScanKind kind;
  final DateTime? expiry;
  final String? batch;
  final String? serial;

  static const _gs = '\u001d';

  /// Fixed-length GS1 application identifiers used on medicine packs.
  static const _fixed = {'01': 14, '02': 14, '11': 6, '15': 6, '17': 6};

  /// Variable-length identifiers; they end with GS or the end of data.
  static const _variable = {'10', '21', '91', '92', '93', '240'};

  static ScannedCode? parse(String rawValue) {
    var value = rawValue.trim();
    for (final prefix in [']d2', ']C1', ']Q3']) {
      if (value.startsWith(prefix)) value = value.substring(prefix.length);
    }
    if (value.startsWith(_gs)) value = value.substring(1);
    if (RegExp(r'^\d{8}$').hasMatch(value)) {
      return ScannedCode(gtin: value.padLeft(14, '0'), kind: ScanKind.barcode);
    }
    if (RegExp(r'^\d{13}$').hasMatch(value)) {
      return ScannedCode(gtin: '0$value', kind: ScanKind.barcode);
    }
    if (RegExp(r'^\d{14}$').hasMatch(value)) {
      return ScannedCode(gtin: value, kind: ScanKind.barcode);
    }
    final fields = _parseGs1(value);
    final gtin = fields['01'];
    if (gtin == null) return null;
    return ScannedCode(
      gtin: gtin,
      kind: ScanKind.dataMatrix,
      expiry: _date(fields['17']),
      batch: fields['10'],
      serial: fields['21'],
    );
  }

  static Map<String, String> _parseGs1(String data) {
    final result = <String, String>{};
    var i = 0;
    while (i < data.length) {
      if (data[i] == _gs) {
        i++;
        continue;
      }
      final ai = _fixed.keys.firstWhere(
        (key) => data.startsWith(key, i),
        orElse: () => _variable.firstWhere(
          (key) => data.startsWith(key, i),
          orElse: () => '',
        ),
      );
      if (ai.isEmpty) break;
      i += ai.length;
      final fixed = _fixed[ai];
      if (fixed != null) {
        if (i + fixed > data.length) break;
        result[ai] = data.substring(i, i + fixed);
        i += fixed;
        continue;
      }
      var end = data.indexOf(_gs, i);
      if (end < 0) {
        // Russian marking codes sometimes lose GS: the serial is 13 chars.
        end = ai == '21' && data.length > i + 13 ? i + 13 : data.length;
      }
      result[ai] = data.substring(i, end);
      i = end;
    }
    return result;
  }

  /// GS1 date YYMMDD; day 00 means the last day of the month.
  static DateTime? _date(String? value) {
    if (value == null || !RegExp(r'^\d{6}$').hasMatch(value)) return null;
    final year = 2000 + int.parse(value.substring(0, 2));
    final month = int.parse(value.substring(2, 4));
    final day = int.parse(value.substring(4, 6));
    if (month < 1 || month > 12 || day > 31) return null;
    return day == 0
        ? DateTime(year, month + 1, 0)
        : DateTime(year, month, day);
  }
}
