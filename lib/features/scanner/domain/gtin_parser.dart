import 'package:aptechka/features/scanner/domain/scanned_code.dart';

abstract final class GtinParser {
  /// GTIN-14 from an EAN-8/13, GTIN-14 or GS1 DataMatrix value.
  static String? parse(String rawValue) => ScannedCode.parse(rawValue)?.gtin;
}
