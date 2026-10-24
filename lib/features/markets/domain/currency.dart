/// The currencies an account can be held in. Instruments quote in more
/// (JPY, CAD, CHF…); those only ever appear as the "from" side of a conversion.
enum AccountCurrency {
  usd('USD', r'$'),
  zar('ZAR', 'R'),
  eur('EUR', '€'),
  gbp('GBP', '£');

  const AccountCurrency(this.code, this.symbol);

  final String code;
  final String symbol;

  static const AccountCurrency fallback = usd;

  /// Null for anything that is not one of the four.
  static AccountCurrency? fromCode(String? code) =>
      AccountCurrency.values.where((c) => c.code == code?.toUpperCase()).firstOrNull;
}
