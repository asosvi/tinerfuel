import 'package:latlong2/latlong.dart';

/// Nombre visible de la app. PROVISIONAL: cambiar aquí (y en las ARB, el
/// manifest de Android, el Info.plist de iOS y web/) cuando se decida el nombre.
const appName = 'Tinerfuel';

/// Se leen de env.json con --dart-define-from-file=env.json (fuera de git).
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
bool get hasBackend => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

/// Web pública (política de privacidad, condiciones...). PROVISIONAL.
const siteUrl = 'https://tinerfuel.example';
const privacyUrl = '$siteUrl/privacy';
const termsUrl = '$siteUrl/terms';

/// Vuelta a la app tras entrar con Google / Apple (Android e iOS).
/// Debe coincidir con AndroidManifest.xml, Info.plist y las "Redirect URLs" de Supabase.
const authRedirectUrl = 'tinerfuel://login-callback';

/// Teselas del mapa. Las de openstreetmap.org NO valen para una app con muchos
/// usuarios (política de uso de OSM): cambiar a un proveedor antes de publicar.
const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const tileUserAgent = 'com.example.tinerfuel';

/// Vista inicial: toda España con Canarias (sin ubicación).
const spainCenter = LatLng(35.8, -7.8);
const spainZoom = 4.9;

/// Zona con datos (península, Baleares, Canarias, Ceuta y Melilla). La caja
/// que se pide a map_points se recorta a esta zona: la base de datos rechaza
/// cajas de más de 40° × 30° (pantallas grandes con poco zoom).
const spainSouthWest = LatLng(27.4, -18.4);
const spainNorthEast = LatLng(44.0, 4.6);
