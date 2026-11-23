import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Packages added in a row from the scanner («Несколько упаковок подряд»,
/// 890:15548), in order. Lives for the session; the summary clears it.
final addBatchProvider = NotifierProvider<AddBatch, List<String>>(
  AddBatch.new,
);

class AddBatch extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void add(String id) => state = [...state, id];

  void clear() => state = const [];
}
