
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Lado máximo que se acepta al leer (más grande = posible "bomba" de imagen:
/// un archivo pequeño que al decodificarse pide gigas de memoria).
const maxSourceSide = 8192;

/// Lado mayor de la foto que se sube.
const maxUploadSide = 1600;

/// Devuelve un JPEG reducido y SIN metadatos (EXIF con la ubicación GPS,
/// modelo del móvil...), o null si la imagen no es válida o es demasiado grande.
Future<Uint8List?> preparePhoto(Uint8List bytes) => compute(preparePhotoSync, bytes);

Uint8List? preparePhotoSync(Uint8List bytes) {
  final decoder = img.findDecoderForData(bytes);
  if (decoder == null || (decoder is! img.JpegDecoder && decoder is! img.PngDecoder)) return null;
  final info = decoder.startDecode(bytes);
  if (info == null || info.width <= 0 || info.height <= 0) return null;
  if (info.width > maxSourceSide || info.height > maxSourceSide) return null;

  var image = decoder.decode(bytes);
  if (image == null) return null;
  image = img.bakeOrientation(image); // gira según el EXIF antes de quitarlo
  if (image.width > maxUploadSide || image.height > maxUploadSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxUploadSide)
        : img.copyResize(image, height: maxUploadSide);
  }
  image.exif = img.ExifData(); // fuera todos los metadatos
  return img.encodeJpg(image, quality: 80);
}
