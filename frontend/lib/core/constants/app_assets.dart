// Asset paths for bundled images and SVG icons used by the UI.
abstract final class AppAssets {
  /// Hero illustration shown on the login and create-account screens.
  static const kuboHero = 'assets/images/kubo_house.jpg';
  /// Fallback product/listing image used when backend images are unavailable.
  static const placeholderImage = 'assets/images/Placeholder_img.png';
}

// SVG icon paths referenced by the app's navigation and toolbars.
abstract final class AppIcons {
  /// Three-line or overflow style icon used for the app drawer trigger.
  static const barsMore = 'assets/icons/bars-more.svg';
  /// Notification bell icon used for alerts and updates actions.
  static const bellNotification = 'assets/icons/bell-notification.svg';
  /// Saved/favorite icon used across listing cards and shortcuts.
  static const heartSaved = 'assets/icons/heart-saved.svg';
  /// Chat bubble icon used for message-related actions.
  static const chat = 'assets/icons/chat.svg';
  /// List-view icon used when toggling the explore feed into card mode.
  static const listView = 'assets/icons/list_view.svg';
  /// Location pin icon used beside the current location label.
  static const locationDot = 'assets/icons/location-dot.svg';
  /// Home tab icon used in bottom navigation and the main landing tab.
  static const home = 'assets/icons/home.svg';
  /// Search tab icon used in the bottom navigation template pages.
  static const search = 'assets/icons/search.svg';
  /// Primary add action icon used for the center tab / floating action flows.
  static const squarePlus = 'assets/icons/square-plus.svg';
  /// Market/analytics icon used for the market or insights tab.
  static const chartLine = 'assets/icons/chart-line.svg';
  /// Profile/account icon used for user-related navigation.
  static const user = 'assets/icons/user.svg';
}