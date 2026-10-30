// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get layerFuel => 'Gasolina';

  @override
  String get layerCharger => 'Carga';

  @override
  String get layerParking => 'Parking';

  @override
  String get fuelLabel => 'Combustible';

  @override
  String get minPower => 'Potencia mínima';

  @override
  String get anyPower => 'Cualquiera';

  @override
  String get myLocation => 'Mi ubicación';

  @override
  String get locationDenied =>
      'Sin permiso de ubicación. El mapa no puede centrarse en ti.';

  @override
  String get locationOff => 'La ubicación está desactivada.';

  @override
  String get cheapestNearby => 'Más baratas cerca';

  @override
  String get chargersNearby => 'Cargadores cerca';

  @override
  String get noBackend =>
      'Servidor no configurado: falta env.json. El mapa se ve, pero sin datos.';

  @override
  String get loadError =>
      'No se pudieron cargar los datos. Comprueba la conexión.';

  @override
  String get retry => 'Reintentar';

  @override
  String get zoomInToSee => 'Acércate para ver los puntos';

  @override
  String groupCount(int count) {
    return '$count puntos';
  }

  @override
  String updatedAgo(String when) {
    return 'Actualizado $when';
  }

  @override
  String agoMinutes(int n) {
    return 'hace $n min';
  }

  @override
  String agoHours(int n) {
    return 'hace $n h';
  }

  @override
  String agoDays(int n) {
    return 'hace $n días';
  }

  @override
  String get justNow => 'ahora mismo';

  @override
  String get prices => 'Precios';

  @override
  String get noPrice => 'Sin precio';

  @override
  String get address => 'Dirección';

  @override
  String get openingHours => 'Horario';

  @override
  String get directions => 'Cómo llegar';

  @override
  String get restrictedSale => 'Venta restringida (solo socios o clientes)';

  @override
  String get operator => 'Operador';

  @override
  String chargePoints(int n) {
    return '$n puntos de carga';
  }

  @override
  String get connectors => 'Conectores';

  @override
  String get noChargerStatus => 'La DGT no publica si está libre ni el precio.';

  @override
  String get parking => 'Parking';

  @override
  String get unnamedParking => 'Parking sin nombre';

  @override
  String capacity(int n) {
    return '$n plazas';
  }

  @override
  String get paid => 'De pago';

  @override
  String get free => 'Gratis';

  @override
  String get kindUnderground => 'Subterráneo';

  @override
  String get kindMultiStorey => 'Varias plantas';

  @override
  String get kindSurface => 'Al aire libre';

  @override
  String get communityPrices => 'Precios de la comunidad';

  @override
  String get noCommunityPrices => 'Nadie ha añadido precios todavía.';

  @override
  String get addPrice => 'Añadir precio';

  @override
  String get reviews => 'Opiniones';

  @override
  String get noReviews => 'Sin opiniones todavía.';

  @override
  String get addReview => 'Opinar';

  @override
  String get editReview => 'Editar mi opinión';

  @override
  String get photos => 'Fotos';

  @override
  String get addPhoto => 'Añadir foto';

  @override
  String get priceKind => 'Tipo de tarifa';

  @override
  String get perHour => 'Por hora';

  @override
  String get perDay => 'Por día';

  @override
  String get perMonth => 'Por mes';

  @override
  String get flatRate => 'Tarifa plana';

  @override
  String get freeOfCharge => 'Gratis';

  @override
  String get amountEuros => 'Importe (€)';

  @override
  String get noteOptional => 'Nota (opcional)';

  @override
  String get rating => 'Valoración';

  @override
  String get commentOptional => 'Comentario (opcional)';

  @override
  String get save => 'Guardar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Borrar';

  @override
  String get saved => 'Guardado. ¡Gracias!';

  @override
  String get invalidAmount => 'Escribe un importe entre 0 y 1000 €.';

  @override
  String get rateLimited => 'Has llegado al máximo de aportaciones de hoy.';

  @override
  String get photoTooBig => 'La imagen no es válida o es demasiado grande.';

  @override
  String get loginRequired => 'Inicia sesión para aportar.';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get account => 'Cuenta';

  @override
  String get email => 'Email';

  @override
  String get sendCode => 'Enviar código';

  @override
  String codeSent(String email) {
    return 'Te hemos enviado un correo a $email. Pulsa el enlace o escribe aquí el código.';
  }

  @override
  String get code => 'Código';

  @override
  String get verify => 'Entrar';

  @override
  String get invalidEmail =>
      'Escribe un email válido (por ejemplo, nombre@ejemplo.com).';

  @override
  String get invalidCode => 'Código incorrecto o caducado.';

  @override
  String get continueWithGoogle => 'Continuar con Google';

  @override
  String get continueWithApple => 'Continuar con Apple';

  @override
  String get orDivider => 'o';

  @override
  String get acceptTerms =>
      'Al entrar aceptas las condiciones de uso y la política de privacidad. Edad mínima: 14 años.';

  @override
  String get displayName => 'Nombre visible';

  @override
  String get deleteAccount => 'Borrar cuenta';

  @override
  String get deleteAccountConfirm =>
      'Se borrarán tu cuenta y todo lo que has aportado (precios, opiniones y fotos). No se puede deshacer. Escribe BORRAR para confirmar.';

  @override
  String get deleteWord => 'BORRAR';

  @override
  String get accountDeleted => 'Cuenta borrada.';

  @override
  String get report => 'Denunciar';

  @override
  String get reportReason => 'Motivo';

  @override
  String get reasonSpam => 'Spam o publicidad';

  @override
  String get reasonOffensive => 'Ofensivo';

  @override
  String get reasonFalse => 'Información falsa';

  @override
  String get reasonPersonalData => 'Datos personales';

  @override
  String get reasonOther => 'Otro';

  @override
  String get detailsOptional => 'Detalles (opcional)';

  @override
  String get reportSent => 'Denuncia enviada. La revisaremos.';

  @override
  String get alreadyReported => 'Ya lo habías denunciado.';

  @override
  String get block => 'Bloquear a esta persona';

  @override
  String get blocked => 'Bloqueada. Ya no verás lo que aporte.';

  @override
  String get blockedUsers => 'Personas bloqueadas';

  @override
  String get unblock => 'Desbloquear';

  @override
  String get noBlockedUsers => 'No has bloqueado a nadie.';

  @override
  String get you => 'Tú';

  @override
  String get privacy => 'Privacidad';

  @override
  String get terms => 'Condiciones de uso';

  @override
  String get about => 'Acerca de';

  @override
  String get dataSources =>
      'Fuentes: Ministerio para la Transición Ecológica (precios), DGT (puntos de carga, CC BY) y © colaboradores de OpenStreetMap (mapa y parkings).';

  @override
  String get language => 'Idioma';

  @override
  String get systemLanguage => 'Idioma del sistema';

  @override
  String get noConnection => 'Sin conexión. Inténtalo de nuevo.';

  @override
  String somethingWrong(String error) {
    return 'Algo ha fallado: $error';
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
  String get noResultsNearby => 'No hay resultados a menos de 10 km.';

  @override
  String get needLocationForList =>
      'Activa la ubicación o mueve el mapa: la lista usa el centro del mapa.';

  @override
  String get fuel_gasolina_95_e5 => 'Gasolina 95';

  @override
  String get fuel_gasolina_95_e10 => 'Gasolina 95 E10';

  @override
  String get fuel_gasolina_95_e5_premium => 'Gasolina 95 Premium';

  @override
  String get fuel_gasolina_98_e5 => 'Gasolina 98';

  @override
  String get fuel_gasolina_98_e10 => 'Gasolina 98 E10';

  @override
  String get fuel_gasoleo_a => 'Diésel';

  @override
  String get fuel_gasoleo_premium => 'Diésel Premium';

  @override
  String get fuel_gasoleo_b => 'Gasóleo B (agrícola)';

  @override
  String get fuel_diesel_renovable => 'Diésel renovable';

  @override
  String get fuel_gasolina_renovable => 'Gasolina renovable';

  @override
  String get fuel_glp => 'GLP (autogás)';

  @override
  String get fuel_gnc => 'Gas natural (GNC)';

  @override
  String get fuel_gnl => 'Gas natural (GNL)';

  @override
  String get fuel_hidrogeno => 'Hidrógeno';

  @override
  String get fuel_adblue => 'AdBlue';
}
