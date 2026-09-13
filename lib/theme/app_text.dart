/// Named type scale for the whole app. Every `fontSize:` in lib/ must use one
/// of these tokens; values are tuned for Inter with a raised 10px floor so
/// nothing renders smaller than before.
class AppText {
  AppText._();

  static const double micro = 10; // badges, overlines, flag chips
  static const double label = 12; // tile labels, list subtitles, small captions
  static const double caption = 13; // secondary body
  static const double body = 14; // primary body
  static const double subtitle = 15.5;
  static const double title = 17; // section/card titles
  static const double headline = 20; // screen headlines, big figures
  static const double display = 26; // hero figures only
}
