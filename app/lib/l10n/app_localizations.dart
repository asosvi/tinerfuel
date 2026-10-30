import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @layerFuel.
  ///
  /// In es, this message translates to:
  /// **'Gasolina'**
  String get layerFuel;

  /// No description provided for @layerCharger.
  ///
  /// In es, this message translates to:
  /// **'Carga'**
  String get layerCharger;

  /// No description provided for @layerParking.
  ///
  /// In es, this message translates to:
  /// **'Parking'**
  String get layerParking;

  /// No description provided for @fuelLabel.
  ///
  /// In es, this message translates to:
  /// **'Combustible'**
  String get fuelLabel;

  /// No description provided for @minPower.
  ///
  /// In es, this message translates to:
  /// **'Potencia mínima'**
  String get minPower;

  /// No description provided for @anyPower.
  ///
  /// In es, this message translates to:
  /// **'Cualquiera'**
  String get anyPower;

  /// No description provided for @myLocation.
  ///
  /// In es, this message translates to:
  /// **'Mi ubicación'**
  String get myLocation;

  /// No description provided for @locationDenied.
  ///
  /// In es, this message translates to:
  /// **'Sin permiso de ubicación. El mapa no puede centrarse en ti.'**
  String get locationDenied;

  /// No description provided for @locationOff.
  ///
  /// In es, this message translates to:
  /// **'La ubicación está desactivada.'**
  String get locationOff;

  /// No description provided for @cheapestNearby.
  ///
  /// In es, this message translates to:
  /// **'Más baratas cerca'**
  String get cheapestNearby;

  /// No description provided for @chargersNearby.
  ///
  /// In es, this message translates to:
  /// **'Cargadores cerca'**
  String get chargersNearby;

  /// No description provided for @noBackend.
  ///
  /// In es, this message translates to:
  /// **'Servidor no configurado: falta env.json. El mapa se ve, pero sin datos.'**
  String get noBackend;

  /// No description provided for @loadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar los datos. Comprueba la conexión.'**
  String get loadError;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @zoomInToSee.
  ///
  /// In es, this message translates to:
  /// **'Acércate para ver los puntos'**
  String get zoomInToSee;

  /// No description provided for @groupCount.
  ///
  /// In es, this message translates to:
  /// **'{count} puntos'**
  String groupCount(int count);

  /// No description provided for @updatedAgo.
  ///
  /// In es, this message translates to:
  /// **'Actualizado {when}'**
  String updatedAgo(String when);

  /// No description provided for @agoMinutes.
  ///
  /// In es, this message translates to:
  /// **'hace {n} min'**
  String agoMinutes(int n);

  /// No description provided for @agoHours.
  ///
  /// In es, this message translates to:
  /// **'hace {n} h'**
  String agoHours(int n);

  /// No description provided for @agoDays.
  ///
  /// In es, this message translates to:
  /// **'hace {n} días'**
  String agoDays(int n);

  /// No description provided for @justNow.
  ///
  /// In es, this message translates to:
  /// **'ahora mismo'**
  String get justNow;

  /// No description provided for @prices.
  ///
  /// In es, this message translates to:
  /// **'Precios'**
  String get prices;

  /// No description provided for @noPrice.
  ///
  /// In es, this message translates to:
  /// **'Sin precio'**
  String get noPrice;

  /// No description provided for @address.
  ///
  /// In es, this message translates to:
  /// **'Dirección'**
  String get address;

  /// No description provided for @openingHours.
  ///
  /// In es, this message translates to:
  /// **'Horario'**
  String get openingHours;

  /// No description provided for @directions.
  ///
  /// In es, this message translates to:
  /// **'Cómo llegar'**
  String get directions;

  /// No description provided for @restrictedSale.
  ///
  /// In es, this message translates to:
  /// **'Venta restringida (solo socios o clientes)'**
  String get restrictedSale;

  /// No description provided for @operator.
  ///
  /// In es, this message translates to:
  /// **'Operador'**
  String get operator;

  /// No description provided for @chargePoints.
  ///
  /// In es, this message translates to:
  /// **'{n} puntos de carga'**
  String chargePoints(int n);

  /// No description provided for @connectors.
  ///
  /// In es, this message translates to:
  /// **'Conectores'**
  String get connectors;

  /// No description provided for @noChargerStatus.
  ///
  /// In es, this message translates to:
  /// **'La DGT no publica si está libre ni el precio.'**
  String get noChargerStatus;

  /// No description provided for @parking.
  ///
  /// In es, this message translates to:
  /// **'Parking'**
  String get parking;

  /// No description provided for @unnamedParking.
  ///
  /// In es, this message translates to:
  /// **'Parking sin nombre'**
  String get unnamedParking;

  /// No description provided for @capacity.
  ///
  /// In es, this message translates to:
  /// **'{n} plazas'**
  String capacity(int n);

  /// No description provided for @paid.
  ///
  /// In es, this message translates to:
  /// **'De pago'**
  String get paid;

  /// No description provided for @free.
  ///
  /// In es, this message translates to:
  /// **'Gratis'**
  String get free;

  /// No description provided for @kindUnderground.
  ///
  /// In es, this message translates to:
  /// **'Subterráneo'**
  String get kindUnderground;

  /// No description provided for @kindMultiStorey.
  ///
  /// In es, this message translates to:
  /// **'Varias plantas'**
  String get kindMultiStorey;

  /// No description provided for @kindSurface.
  ///
  /// In es, this message translates to:
  /// **'Al aire libre'**
  String get kindSurface;

  /// No description provided for @communityPrices.
  ///
  /// In es, this message translates to:
  /// **'Precios de la comunidad'**
  String get communityPrices;

  /// No description provided for @noCommunityPrices.
  ///
  /// In es, this message translates to:
  /// **'Nadie ha añadido precios todavía.'**
  String get noCommunityPrices;

  /// No description provided for @addPrice.
  ///
  /// In es, this message translates to:
  /// **'Añadir precio'**
  String get addPrice;

  /// No description provided for @reviews.
  ///
  /// In es, this message translates to:
  /// **'Opiniones'**
  String get reviews;

  /// No description provided for @noReviews.
  ///
  /// In es, this message translates to:
  /// **'Sin opiniones todavía.'**
  String get noReviews;

  /// No description provided for @addReview.
  ///
  /// In es, this message translates to:
  /// **'Opinar'**
  String get addReview;

  /// No description provided for @editReview.
  ///
  /// In es, this message translates to:
  /// **'Editar mi opinión'**
  String get editReview;

  /// No description provided for @photos.
  ///
  /// In es, this message translates to:
  /// **'Fotos'**
  String get photos;

  /// No description provided for @addPhoto.
  ///
  /// In es, this message translates to:
  /// **'Añadir foto'**
  String get addPhoto;

  /// No description provided for @priceKind.
  ///
  /// In es, this message translates to:
  /// **'Tipo de tarifa'**
  String get priceKind;

  /// No description provided for @perHour.
  ///
  /// In es, this message translates to:
  /// **'Por hora'**
  String get perHour;

  /// No description provided for @perDay.
  ///
  /// In es, this message translates to:
  /// **'Por día'**
  String get perDay;

  /// No description provided for @perMonth.
  ///
  /// In es, this message translates to:
  /// **'Por mes'**
  String get perMonth;

  /// No description provided for @flatRate.
  ///
  /// In es, this message translates to:
  /// **'Tarifa plana'**
  String get flatRate;

  /// No description provided for @freeOfCharge.
  ///
  /// In es, this message translates to:
  /// **'Gratis'**
  String get freeOfCharge;

  /// No description provided for @amountEuros.
  ///
  /// In es, this message translates to:
  /// **'Importe (€)'**
  String get amountEuros;

  /// No description provided for @noteOptional.
  ///
  /// In es, this message translates to:
  /// **'Nota (opcional)'**
  String get noteOptional;

  /// No description provided for @rating.
  ///
  /// In es, this message translates to:
  /// **'Valoración'**
  String get rating;

  /// No description provided for @commentOptional.
  ///
  /// In es, this message translates to:
  /// **'Comentario (opcional)'**
  String get commentOptional;

  /// No description provided for @save.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In es, this message translates to:
  /// **'Borrar'**
  String get delete;

  /// No description provided for @saved.
  ///
  /// In es, this message translates to:
  /// **'Guardado. ¡Gracias!'**
  String get saved;

  /// No description provided for @invalidAmount.
  ///
  /// In es, this message translates to:
  /// **'Escribe un importe entre 0 y 1000 €.'**
  String get invalidAmount;

  /// No description provided for @rateLimited.
  ///
  /// In es, this message translates to:
  /// **'Has llegado al máximo de aportaciones de hoy.'**
  String get rateLimited;

  /// No description provided for @photoTooBig.
  ///
  /// In es, this message translates to:
  /// **'La imagen no es válida o es demasiado grande.'**
  String get photoTooBig;

  /// No description provided for @loginRequired.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión para aportar.'**
  String get loginRequired;

  /// No description provided for @signIn.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get signOut;

  /// No description provided for @account.
  ///
  /// In es, this message translates to:
  /// **'Cuenta'**
  String get account;

  /// No description provided for @email.
  ///
  /// In es, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @sendCode.
  ///
  /// In es, this message translates to:
  /// **'Enviar código'**
  String get sendCode;

  /// No description provided for @codeSent.
  ///
  /// In es, this message translates to:
  /// **'Te hemos enviado un correo a {email}. Pulsa el enlace o escribe aquí el código.'**
  String codeSent(String email);

  /// No description provided for @code.
  ///
  /// In es, this message translates to:
  /// **'Código'**
  String get code;

  /// No description provided for @verify.
  ///
  /// In es, this message translates to:
  /// **'Entrar'**
  String get verify;

  /// No description provided for @invalidEmail.
  ///
  /// In es, this message translates to:
  /// **'Escribe un email válido (por ejemplo, nombre@ejemplo.com).'**
  String get invalidEmail;

  /// No description provided for @invalidCode.
  ///
  /// In es, this message translates to:
  /// **'Código incorrecto o caducado.'**
  String get invalidCode;

  /// No description provided for @continueWithGoogle.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Apple'**
  String get continueWithApple;

  /// No description provided for @orDivider.
  ///
  /// In es, this message translates to:
  /// **'o'**
  String get orDivider;

  /// No description provided for @acceptTerms.
  ///
  /// In es, this message translates to:
  /// **'Al entrar aceptas las condiciones de uso y la política de privacidad. Edad mínima: 14 años.'**
  String get acceptTerms;

  /// No description provided for @displayName.
  ///
  /// In es, this message translates to:
  /// **'Nombre visible'**
  String get displayName;

  /// No description provided for @deleteAccount.
  ///
  /// In es, this message translates to:
  /// **'Borrar cuenta'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In es, this message translates to:
  /// **'Se borrarán tu cuenta y todo lo que has aportado (precios, opiniones y fotos). No se puede deshacer. Escribe BORRAR para confirmar.'**
  String get deleteAccountConfirm;

  /// No description provided for @deleteWord.
  ///
  /// In es, this message translates to:
  /// **'BORRAR'**
  String get deleteWord;

  /// No description provided for @accountDeleted.
  ///
  /// In es, this message translates to:
  /// **'Cuenta borrada.'**
  String get accountDeleted;

  /// No description provided for @report.
  ///
  /// In es, this message translates to:
  /// **'Denunciar'**
  String get report;

  /// No description provided for @reportReason.
  ///
  /// In es, this message translates to:
  /// **'Motivo'**
  String get reportReason;

  /// No description provided for @reasonSpam.
  ///
  /// In es, this message translates to:
  /// **'Spam o publicidad'**
  String get reasonSpam;

  /// No description provided for @reasonOffensive.
  ///
  /// In es, this message translates to:
  /// **'Ofensivo'**
  String get reasonOffensive;

  /// No description provided for @reasonFalse.
  ///
  /// In es, this message translates to:
  /// **'Información falsa'**
  String get reasonFalse;

  /// No description provided for @reasonPersonalData.
  ///
  /// In es, this message translates to:
  /// **'Datos personales'**
  String get reasonPersonalData;

  /// No description provided for @reasonOther.
  ///
  /// In es, this message translates to:
  /// **'Otro'**
  String get reasonOther;

  /// No description provided for @detailsOptional.
  ///
  /// In es, this message translates to:
  /// **'Detalles (opcional)'**
  String get detailsOptional;

  /// No description provided for @reportSent.
  ///
  /// In es, this message translates to:
  /// **'Denuncia enviada. La revisaremos.'**
  String get reportSent;

  /// No description provided for @alreadyReported.
  ///
  /// In es, this message translates to:
  /// **'Ya lo habías denunciado.'**
  String get alreadyReported;

  /// No description provided for @block.
  ///
  /// In es, this message translates to:
  /// **'Bloquear a esta persona'**
  String get block;

  /// No description provided for @blocked.
  ///
  /// In es, this message translates to:
  /// **'Bloqueada. Ya no verás lo que aporte.'**
  String get blocked;

  /// No description provided for @blockedUsers.
  ///
  /// In es, this message translates to:
  /// **'Personas bloqueadas'**
  String get blockedUsers;

  /// No description provided for @unblock.
  ///
  /// In es, this message translates to:
  /// **'Desbloquear'**
  String get unblock;

  /// No description provided for @noBlockedUsers.
  ///
  /// In es, this message translates to:
  /// **'No has bloqueado a nadie.'**
  String get noBlockedUsers;

  /// No description provided for @you.
  ///
  /// In es, this message translates to:
  /// **'Tú'**
  String get you;

  /// No description provided for @privacy.
  ///
  /// In es, this message translates to:
  /// **'Privacidad'**
  String get privacy;

  /// No description provided for @terms.
  ///
  /// In es, this message translates to:
  /// **'Condiciones de uso'**
  String get terms;

  /// No description provided for @about.
  ///
  /// In es, this message translates to:
  /// **'Acerca de'**
  String get about;

  /// No description provided for @dataSources.
  ///
  /// In es, this message translates to:
  /// **'Fuentes: Ministerio para la Transición Ecológica (precios), DGT (puntos de carga, CC BY) y © colaboradores de OpenStreetMap (mapa y parkings).'**
  String get dataSources;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @systemLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma del sistema'**
  String get systemLanguage;

  /// No description provided for @noConnection.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión. Inténtalo de nuevo.'**
  String get noConnection;

  /// No description provided for @somethingWrong.
  ///
  /// In es, this message translates to:
  /// **'Algo ha fallado: {error}'**
  String somethingWrong(String error);

  /// No description provided for @km.
  ///
  /// In es, this message translates to:
  /// **'{d} km'**
  String km(String d);

  /// No description provided for @meters.
  ///
  /// In es, this message translates to:
  /// **'{d} m'**
  String meters(int d);

  /// No description provided for @noResultsNearby.
  ///
  /// In es, this message translates to:
  /// **'No hay resultados a menos de 10 km.'**
  String get noResultsNearby;

  /// No description provided for @needLocationForList.
  ///
  /// In es, this message translates to:
  /// **'Activa la ubicación o mueve el mapa: la lista usa el centro del mapa.'**
  String get needLocationForList;

  /// No description provided for @fuel_gasolina_95_e5.
  ///
  /// In es, this message translates to:
  /// **'Gasolina 95'**
  String get fuel_gasolina_95_e5;

  /// No description provided for @fuel_gasolina_95_e10.
  ///
  /// In es, this message translates to:
  /// **'Gasolina 95 E10'**
  String get fuel_gasolina_95_e10;

  /// No description provided for @fuel_gasolina_95_e5_premium.
  ///
  /// In es, this message translates to:
  /// **'Gasolina 95 Premium'**
  String get fuel_gasolina_95_e5_premium;

  /// No description provided for @fuel_gasolina_98_e5.
  ///
  /// In es, this message translates to:
  /// **'Gasolina 98'**
  String get fuel_gasolina_98_e5;

  /// No description provided for @fuel_gasolina_98_e10.
  ///
  /// In es, this message translates to:
  /// **'Gasolina 98 E10'**
  String get fuel_gasolina_98_e10;

  /// No description provided for @fuel_gasoleo_a.
  ///
  /// In es, this message translates to:
  /// **'Diésel'**
  String get fuel_gasoleo_a;

  /// No description provided for @fuel_gasoleo_premium.
  ///
  /// In es, this message translates to:
  /// **'Diésel Premium'**
  String get fuel_gasoleo_premium;

  /// No description provided for @fuel_gasoleo_b.
  ///
  /// In es, this message translates to:
  /// **'Gasóleo B (agrícola)'**
  String get fuel_gasoleo_b;

  /// No description provided for @fuel_diesel_renovable.
  ///
  /// In es, this message translates to:
  /// **'Diésel renovable'**
  String get fuel_diesel_renovable;

  /// No description provided for @fuel_gasolina_renovable.
  ///
  /// In es, this message translates to:
  /// **'Gasolina renovable'**
  String get fuel_gasolina_renovable;

  /// No description provided for @fuel_glp.
  ///
  /// In es, this message translates to:
  /// **'GLP (autogás)'**
  String get fuel_glp;

  /// No description provided for @fuel_gnc.
  ///
  /// In es, this message translates to:
  /// **'Gas natural (GNC)'**
  String get fuel_gnc;

  /// No description provided for @fuel_gnl.
  ///
  /// In es, this message translates to:
  /// **'Gas natural (GNL)'**
  String get fuel_gnl;

  /// No description provided for @fuel_hidrogeno.
  ///
  /// In es, this message translates to:
  /// **'Hidrógeno'**
  String get fuel_hidrogeno;

  /// No description provided for @fuel_adblue.
  ///
  /// In es, this message translates to:
  /// **'AdBlue'**
  String get fuel_adblue;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
