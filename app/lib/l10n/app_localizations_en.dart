// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get layerFuel => 'Fuel';

  @override
  String get layerCharger => 'Charging';

  @override
  String get layerParking => 'Parking';

  @override
  String get fuelLabel => 'Fuel';

  @override
  String get minPower => 'Minimum power';

  @override
  String get anyPower => 'Any';

  @override
  String get myLocation => 'My location';

  @override
  String get locationDenied =>
      'No location permission. The map can\'t centre on you.';

  @override
  String get locationOff => 'Location services are off.';

  @override
  String get cheapestNearby => 'Cheapest nearby';

  @override
  String get chargersNearby => 'Chargers nearby';

  @override
  String get noBackend =>
      'Server not configured: env.json is missing. The map works, but without data.';

  @override
  String get loadError => 'Couldn\'t load the data. Check your connection.';

  @override
  String get retry => 'Retry';

  @override
  String get zoomInToSee => 'Zoom in to see the points';

  @override
  String groupCount(int count) {
    return '$count places';
  }

  @override
  String updatedAgo(String when) {
    return 'Updated $when';
  }

  @override
  String agoMinutes(int n) {
    return '$n min ago';
  }

  @override
  String agoHours(int n) {
    return '$n h ago';
  }

  @override
  String agoDays(int n) {
    return '$n days ago';
  }

  @override
  String get justNow => 'just now';

  @override
  String get prices => 'Prices';

  @override
  String get noPrice => 'No price';

  @override
  String get address => 'Address';

  @override
  String get openingHours => 'Opening hours';

  @override
  String get directions => 'Directions';

  @override
  String get restrictedSale => 'Restricted sale (members or customers only)';

  @override
  String get operator => 'Operator';

  @override
  String chargePoints(int n) {
    return '$n charging points';
  }

  @override
  String get connectors => 'Connectors';

  @override
  String get noChargerStatus =>
      'The DGT doesn\'t publish availability or prices.';

  @override
  String get parking => 'Parking';

  @override
  String get unnamedParking => 'Unnamed car park';

  @override
  String capacity(int n) {
    return '$n spaces';
  }

  @override
  String get paid => 'Paid';

  @override
  String get free => 'Free';

  @override
  String get kindUnderground => 'Underground';

  @override
  String get kindMultiStorey => 'Multi-storey';

  @override
  String get kindSurface => 'Open-air';

  @override
  String get communityPrices => 'Community prices';

  @override
  String get noCommunityPrices => 'Nobody has added prices yet.';

  @override
  String get addPrice => 'Add price';

  @override
  String get reviews => 'Reviews';

  @override
  String get noReviews => 'No reviews yet.';

  @override
  String get addReview => 'Review';

  @override
  String get editReview => 'Edit my review';

  @override
  String get photos => 'Photos';

  @override
  String get addPhoto => 'Add photo';

  @override
  String get priceKind => 'Rate type';

  @override
  String get perHour => 'Per hour';

  @override
  String get perDay => 'Per day';

  @override
  String get perMonth => 'Per month';

  @override
  String get flatRate => 'Flat rate';

  @override
  String get freeOfCharge => 'Free';

  @override
  String get amountEuros => 'Amount (€)';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get rating => 'Rating';

  @override
  String get commentOptional => 'Comment (optional)';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get saved => 'Saved. Thank you!';

  @override
  String get invalidAmount => 'Enter an amount between 0 and 1000 €.';

  @override
  String get rateLimited => 'You\'ve reached today\'s contribution limit.';

  @override
  String get photoTooBig => 'The image isn\'t valid or is too large.';

  @override
  String get loginRequired => 'Sign in to contribute.';

  @override
  String get signIn => 'Sign in';

  @override
  String get signOut => 'Sign out';

  @override
  String get account => 'Account';

  @override
  String get email => 'Email';

  @override
  String get sendCode => 'Send code';

  @override
  String codeSent(String email) {
    return 'We\'ve sent a code to $email.';
  }

  @override
  String get code => 'Code';

  @override
  String get verify => 'Sign in';

  @override
  String get invalidEmail =>
      'Enter a valid email address (for example, name@example.com).';

  @override
  String get invalidCode => 'Wrong or expired code.';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get orDivider => 'or';

  @override
  String get acceptTerms =>
      'By signing in you accept the Terms of use and the Privacy policy. Minimum age: 14.';

  @override
  String get displayName => 'Display name';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountConfirm =>
      'Your account and everything you\'ve contributed (prices, reviews and photos) will be deleted. This can\'t be undone. Type DELETE to confirm.';

  @override
  String get deleteWord => 'DELETE';

  @override
  String get accountDeleted => 'Account deleted.';

  @override
  String get report => 'Report';

  @override
  String get reportReason => 'Reason';

  @override
  String get reasonSpam => 'Spam or advertising';

  @override
  String get reasonOffensive => 'Offensive';

  @override
  String get reasonFalse => 'False information';

  @override
  String get reasonPersonalData => 'Personal data';

  @override
  String get reasonOther => 'Other';

  @override
  String get detailsOptional => 'Details (optional)';

  @override
  String get reportSent => 'Report sent. We\'ll review it.';

  @override
  String get alreadyReported => 'You\'ve already reported this.';

  @override
  String get block => 'Block this person';

  @override
  String get blocked => 'Blocked. You won\'t see their contributions.';

  @override
  String get blockedUsers => 'Blocked people';

  @override
  String get unblock => 'Unblock';

  @override
  String get noBlockedUsers => 'You haven\'t blocked anyone.';

  @override
  String get you => 'You';

  @override
  String get privacy => 'Privacy';

  @override
  String get terms => 'Terms of use';

  @override
  String get about => 'About';

  @override
  String get dataSources =>
      'Sources: Spanish Ministry for the Ecological Transition (prices), DGT (charging points, CC BY) and © OpenStreetMap contributors (map and car parks).';

  @override
  String get language => 'Language';

  @override
  String get systemLanguage => 'System language';

  @override
  String get noConnection => 'No connection. Please try again.';

  @override
  String somethingWrong(String error) {
    return 'Something went wrong: $error';
  }

  @override
  String km(String d) {
    return '$d km';
  }

  @override
  String meters(int d) {
    return '$d m';
  }

  @override
  String get noResultsNearby => 'No results within 10 km.';

  @override
  String get needLocationForList =>
      'Turn on location or move the map: the list uses the centre of the map.';

  @override
  String get fuel_gasolina_95_e5 => 'Petrol 95';

  @override
  String get fuel_gasolina_95_e10 => 'Petrol 95 E10';

  @override
  String get fuel_gasolina_95_e5_premium => 'Petrol 95 Premium';

  @override
  String get fuel_gasolina_98_e5 => 'Petrol 98';

  @override
  String get fuel_gasolina_98_e10 => 'Petrol 98 E10';

  @override
  String get fuel_gasoleo_a => 'Diesel';

  @override
  String get fuel_gasoleo_premium => 'Diesel Premium';

  @override
  String get fuel_gasoleo_b => 'Diesel B (agricultural)';

  @override
  String get fuel_diesel_renovable => 'Renewable diesel';

  @override
  String get fuel_gasolina_renovable => 'Renewable petrol';

  @override
  String get fuel_glp => 'LPG (autogas)';

  @override
  String get fuel_gnc => 'Natural gas (CNG)';

  @override
  String get fuel_gnl => 'Natural gas (LNG)';

  @override
  String get fuel_hidrogeno => 'Hydrogen';

  @override
  String get fuel_adblue => 'AdBlue';
}
