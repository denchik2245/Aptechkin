/// Divisions of the Figma «stock control / level» (874:12559): the
/// approximate remainder of drops, syrups, creams and sprays.
/// The enum name is persisted.
enum StockLevel {
  almostEmpty('Почти пусто'),
  lessThanHalf('Меньше половины'),
  moreThanHalf('Больше половины'),
  full('Полный');

  const StockLevel(this.label);
  final String label;

  static StockLevel? parse(String? value) =>
      StockLevel.values.where((item) => item.name == value).firstOrNull;
}
