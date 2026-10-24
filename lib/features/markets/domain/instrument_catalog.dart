import 'instrument.dart';
import 'market_hours.dart';

/// The instruments doji knows. Typical broker specs: brokers differ, so
/// TODO(next-slice): overwrite from the broker / feed once connected.
/// Futures and stocks are here for the model but hidden in the UI
/// (`AssetClass.shownInUi`).
const List<Instrument> instrumentCatalog = [
  // --- forex ----------------------------------------------------------------
  Instrument(
    symbol: 'EURUSD',
    name: 'euro',
    assetClass: AssetClass.forex,
    group: InstrumentGroup.forex,
    hours: MarketHours.forexWeek,
    tickSize: 0.00001,
    contractSize: 100000,
    aliases: ['EUR/USD', 'EURO', 'FIBER'],
  ),
  Instrument(
    symbol: 'GBPUSD',
    name: 'cable',
    assetClass: AssetClass.forex,
    group: InstrumentGroup.forex,
    hours: MarketHours.forexWeek,
    tickSize: 0.00001,
    contractSize: 100000,
    aliases: ['GBP/USD', 'CABLE', 'POUND'],
  ),
  Instrument(
    symbol: 'USDJPY',
    name: 'yen',
    assetClass: AssetClass.forex,
    group: InstrumentGroup.forex,
    hours: MarketHours.forexWeek,
    quoteCurrency: 'JPY',
    tickSize: 0.001,
    contractSize: 100000,
    aliases: ['USD/JPY', 'YEN', 'GOPHER'],
  ),
  Instrument(
    symbol: 'AUDUSD',
    name: 'aussie',
    assetClass: AssetClass.forex,
    group: InstrumentGroup.forex,
    hours: MarketHours.forexWeek,
    tickSize: 0.00001,
    contractSize: 100000,
    aliases: ['AUD/USD', 'AUSSIE'],
  ),
  Instrument(
    symbol: 'USDCAD',
    name: 'loonie',
    assetClass: AssetClass.forex,
    group: InstrumentGroup.forex,
    hours: MarketHours.forexWeek,
    quoteCurrency: 'CAD',
    tickSize: 0.00001,
    contractSize: 100000,
    aliases: ['USD/CAD', 'LOONIE'],
  ),
  Instrument(
    symbol: 'USDCHF',
    name: 'swissy',
    assetClass: AssetClass.forex,
    group: InstrumentGroup.forex,
    hours: MarketHours.forexWeek,
    quoteCurrency: 'CHF',
    tickSize: 0.00001,
    contractSize: 100000,
    aliases: ['USD/CHF', 'SWISSY', 'SWISS'],
  ),

  // --- CFDs: metals ----------------------------------------------------------
  Instrument(
    symbol: 'XAUUSD',
    name: 'gold',
    assetClass: AssetClass.cfd,
    group: InstrumentGroup.metals,
    hours: MarketHours.forexWeek,
    tickSize: 0.01,
    contractSize: 100,
    aliases: ['GOLD', 'XAU/USD', 'XAU'],
    fastMover: true,
  ),
  Instrument(
    symbol: 'XAGUSD',
    name: 'silver',
    assetClass: AssetClass.cfd,
    group: InstrumentGroup.metals,
    hours: MarketHours.forexWeek,
    tickSize: 0.001,
    contractSize: 5000,
    aliases: ['SILVER', 'XAG/USD', 'XAG'],
  ),

  // --- CFDs: indices ---------------------------------------------------------
  Instrument(
    symbol: 'NAS100',
    name: 'nasdaq',
    assetClass: AssetClass.cfd,
    group: InstrumentGroup.indices,
    hours: MarketHours.forexWeek,
    tickSize: 0.1,
    contractSize: 1,
    aliases: ['NASDAQ', 'US100', 'USTEC', 'NDX'],
    fastMover: true,
  ),
  Instrument(
    symbol: 'US30',
    name: 'the dow',
    assetClass: AssetClass.cfd,
    group: InstrumentGroup.indices,
    hours: MarketHours.forexWeek,
    tickSize: 0.1,
    contractSize: 1,
    aliases: ['DOW', 'DJ30', 'WS30', 'DJI'],
    fastMover: true,
  ),
  Instrument(
    symbol: 'US500',
    name: 'the s&p',
    assetClass: AssetClass.cfd,
    group: InstrumentGroup.indices,
    hours: MarketHours.forexWeek,
    tickSize: 0.1,
    contractSize: 1,
    aliases: ['SPX500', 'SP500', 'SPX', 'S&P'],
  ),
  Instrument(
    symbol: 'GER40',
    name: 'the dax',
    assetClass: AssetClass.cfd,
    group: InstrumentGroup.indices,
    hours: MarketHours.forexWeek,
    quoteCurrency: 'EUR',
    tickSize: 0.1,
    contractSize: 1,
    aliases: ['DAX', 'DE40', 'GER30', 'DE30'],
  ),
  Instrument(
    symbol: 'UK100',
    name: 'the ftse',
    assetClass: AssetClass.cfd,
    group: InstrumentGroup.indices,
    hours: MarketHours.forexWeek,
    quoteCurrency: 'GBP',
    tickSize: 0.1,
    contractSize: 1,
    aliases: ['FTSE', 'FTSE100'],
  ),

  // --- CFDs: oil -------------------------------------------------------------
  Instrument(
    symbol: 'USOIL',
    name: 'us oil',
    assetClass: AssetClass.cfd,
    group: InstrumentGroup.oil,
    hours: MarketHours.forexWeek,
    tickSize: 0.01,
    contractSize: 1000,
    aliases: ['WTI', 'CRUDE', 'XTIUSD', 'CL'],
  ),
  Instrument(
    symbol: 'UKOIL',
    name: 'brent',
    assetClass: AssetClass.cfd,
    group: InstrumentGroup.oil,
    hours: MarketHours.forexWeek,
    tickSize: 0.01,
    contractSize: 1000,
    aliases: ['BRENT', 'XBRUSD'],
  ),

  // --- crypto (24/7) -----------------------------------------------------------
  Instrument(
    symbol: 'BTCUSD',
    name: 'bitcoin',
    assetClass: AssetClass.crypto,
    group: InstrumentGroup.crypto,
    hours: MarketHours.always(),
    tickSize: 0.01,
    contractSize: 1,
    aliases: ['BITCOIN', 'BTC', 'BTC/USD', 'XBT'],
    fastMover: true,
  ),
  Instrument(
    symbol: 'ETHUSD',
    name: 'ether',
    assetClass: AssetClass.crypto,
    group: InstrumentGroup.crypto,
    hours: MarketHours.always(),
    tickSize: 0.01,
    contractSize: 1,
    aliases: ['ETHEREUM', 'ETH', 'ETH/USD'],
    fastMover: true,
  ),
  Instrument(
    symbol: 'SOLUSD',
    name: 'solana',
    assetClass: AssetClass.crypto,
    group: InstrumentGroup.crypto,
    hours: MarketHours.always(),
    tickSize: 0.01,
    contractSize: 1,
    aliases: ['SOLANA', 'SOL', 'SOL/USD'],
    fastMover: true,
  ),

  // --- Deriv synthetic indices (24/7). Sizing comes from Deriv's symbol spec
  // once connected, so tick and contract sizes stay null here. --------------
  Instrument(
    symbol: 'R_10',
    label: 'Volatility 10',
    name: 'volatility 10',
    assetClass: AssetClass.synthetic,
    group: InstrumentGroup.volatility,
    hours: MarketHours.always(),
    aliases: ['VOLATILITY 10', 'VOL10', 'V10', 'VOLATILITY 10 INDEX'],
  ),
  Instrument(
    symbol: 'R_25',
    label: 'Volatility 25',
    name: 'volatility 25',
    assetClass: AssetClass.synthetic,
    group: InstrumentGroup.volatility,
    hours: MarketHours.always(),
    aliases: ['VOLATILITY 25', 'VOL25', 'V25', 'VOLATILITY 25 INDEX'],
  ),
  Instrument(
    symbol: 'R_50',
    label: 'Volatility 50',
    name: 'volatility 50',
    assetClass: AssetClass.synthetic,
    group: InstrumentGroup.volatility,
    hours: MarketHours.always(),
    aliases: ['VOLATILITY 50', 'VOL50', 'V50', 'VOLATILITY 50 INDEX'],
    fastMover: true,
  ),
  Instrument(
    symbol: 'R_75',
    label: 'Volatility 75',
    name: 'volatility 75',
    assetClass: AssetClass.synthetic,
    group: InstrumentGroup.volatility,
    hours: MarketHours.always(),
    aliases: ['VOLATILITY 75', 'VOL75', 'V75', 'VOLATILITY 75 INDEX'],
    fastMover: true,
  ),
  Instrument(
    symbol: 'R_100',
    label: 'Volatility 100',
    name: 'volatility 100',
    assetClass: AssetClass.synthetic,
    group: InstrumentGroup.volatility,
    hours: MarketHours.always(),
    aliases: ['VOLATILITY 100', 'VOL100', 'V100', 'VOLATILITY 100 INDEX'],
    fastMover: true,
  ),
  Instrument(
    symbol: 'BOOM300N',
    label: 'Boom 300',
    name: 'boom 300',
    assetClass: AssetClass.synthetic,
    group: InstrumentGroup.boomCrash,
    hours: MarketHours.always(),
    aliases: ['BOOM 300', 'BOOM300', 'BOOM 300 INDEX'],
    fastMover: true,
  ),
  Instrument(
    symbol: 'BOOM500',
    label: 'Boom 500',
    name: 'boom 500',
    assetClass: AssetClass.synthetic,
    group: InstrumentGroup.boomCrash,
    hours: MarketHours.always(),
    aliases: ['BOOM 500', 'BOOM 500 INDEX'],
    fastMover: true,
  ),
  Instrument(
    symbol: 'BOOM1000',
    label: 'Boom 1000',
    name: 'boom 1000',
    assetClass: AssetClass.synthetic,
    group: InstrumentGroup.boomCrash,
    hours: MarketHours.always(),
    aliases: ['BOOM 1000', 'BOOM 1000 INDEX'],
    fastMover: true,
  ),
  Instrument(
    symbol: 'CRASH300N',
    label: 'Crash 300',
    name: 'crash 300',
    assetClass: AssetClass.synthetic,
    group: InstrumentGroup.boomCrash,
    hours: MarketHours.always(),
    aliases: ['CRASH 300', 'CRASH300', 'CRASH 300 INDEX'],
    fastMover: true,
  ),
  Instrument(
    symbol: 'CRASH500',
    label: 'Crash 500',
    name: 'crash 500',
    assetClass: AssetClass.synthetic,
    group: InstrumentGroup.boomCrash,
    hours: MarketHours.always(),
    aliases: ['CRASH 500', 'CRASH 500 INDEX'],
    fastMover: true,
  ),
  Instrument(
    symbol: 'CRASH1000',
    label: 'Crash 1000',
    name: 'crash 1000',
    assetClass: AssetClass.synthetic,
    group: InstrumentGroup.boomCrash,
    hours: MarketHours.always(),
    aliases: ['CRASH 1000', 'CRASH 1000 INDEX'],
    fastMover: true,
  ),

  // --- futures (model only, hidden) -------------------------------------------
  Instrument(
    symbol: 'ES',
    name: 'e-mini s&p',
    assetClass: AssetClass.futures,
    group: InstrumentGroup.futures,
    hours: MarketHours.futuresWeek,
    tickSize: 0.25,
    tickValue: 12.5,
    contractSize: 50,
    aliases: ['MES', 'E-MINI', 'S&P FUTURES'],
  ),
  Instrument(
    symbol: 'NQ',
    name: 'e-mini nasdaq',
    assetClass: AssetClass.futures,
    group: InstrumentGroup.futures,
    hours: MarketHours.futuresWeek,
    tickSize: 0.25,
    tickValue: 5,
    contractSize: 20,
    aliases: ['MNQ', 'NASDAQ FUTURES'],
    fastMover: true,
  ),
  Instrument(
    symbol: 'GC',
    name: 'gold futures',
    assetClass: AssetClass.futures,
    group: InstrumentGroup.futures,
    hours: MarketHours.futuresWeek,
    tickSize: 0.1,
    tickValue: 10,
    contractSize: 100,
    aliases: ['MGC', 'GOLD FUTURES'],
    fastMover: true,
  ),
  Instrument(
    symbol: 'CL',
    name: 'crude futures',
    assetClass: AssetClass.futures,
    group: InstrumentGroup.futures,
    hours: MarketHours.futuresWeek,
    tickSize: 0.01,
    tickValue: 10,
    contractSize: 1000,
    aliases: ['MCL', 'CRUDE FUTURES'],
  ),

  // --- stocks (model only, hidden) ---------------------------------------------
  Instrument(
    symbol: 'AAPL',
    name: 'apple',
    assetClass: AssetClass.stock,
    group: InstrumentGroup.stocks,
    hours: MarketHours.usStocks,
    tickSize: 0.01,
    contractSize: 1,
    aliases: ['APPLE'],
  ),
  Instrument(
    symbol: 'MSFT',
    name: 'microsoft',
    assetClass: AssetClass.stock,
    group: InstrumentGroup.stocks,
    hours: MarketHours.usStocks,
    tickSize: 0.01,
    contractSize: 1,
    aliases: ['MICROSOFT'],
  ),
  Instrument(
    symbol: 'TSLA',
    name: 'tesla',
    assetClass: AssetClass.stock,
    group: InstrumentGroup.stocks,
    hours: MarketHours.usStocks,
    tickSize: 0.01,
    contractSize: 1,
    aliases: ['TESLA'],
    fastMover: true,
  ),
  Instrument(
    symbol: 'NVDA',
    name: 'nvidia',
    assetClass: AssetClass.stock,
    group: InstrumentGroup.stocks,
    hours: MarketHours.usStocks,
    tickSize: 0.01,
    contractSize: 1,
    aliases: ['NVIDIA'],
    fastMover: true,
  ),
];

/// What the markets step offers: every class that is switched on.
final List<Instrument> visibleInstruments = [
  for (final i in instrumentCatalog)
    if (i.assetClass.shownInUi) i,
];

/// Used until the user picks instruments (or when they skipped the step).
const List<String> defaultInstruments = ['XAUUSD', 'EURUSD'];

final Map<String, Instrument> _bySymbol = {for (final i in instrumentCatalog) i.symbol: i};

/// Null for symbols doji doesn't know (the "+ custom" ones).
Instrument? instrumentBySymbol(String symbol) => _bySymbol[symbol.toUpperCase()];

/// Chip / sheet text for a symbol, known or custom.
String instrumentLabel(String symbol) => instrumentBySymbol(symbol)?.displayLabel ?? symbol;

/// Search: symbol, label or any alias contains [query] (case-insensitive).
bool instrumentMatches(String symbol, String query) {
  final q = query.trim().toUpperCase();
  if (q.isEmpty) return true;
  final i = instrumentBySymbol(symbol);
  if (symbol.toUpperCase().contains(q)) return true;
  if (i == null) return false;
  return i.displayLabel.toUpperCase().contains(q) || i.aliases.any((a) => a.toUpperCase().contains(q));
}

/// True when [query] spells exactly a known instrument, so "+ add" is not offered.
bool instrumentIsExact(String symbol, String query) {
  final q = query.trim().toUpperCase();
  final i = instrumentBySymbol(symbol);
  if (symbol.toUpperCase() == q) return true;
  return i != null && (i.displayLabel.toUpperCase() == q || i.aliases.any((a) => a.toUpperCase() == q));
}
