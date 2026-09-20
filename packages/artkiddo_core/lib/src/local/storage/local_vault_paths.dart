/// Stable on-device directory names used by the local vault and rescue export.
///
/// This file deliberately has no database dependency so file recovery remains
/// available when the Drift database cannot be opened.
abstract final class LocalVaultPaths {
  static const masterpiecesFolder = 'masterpieces';
  static const derivativesFolder = 'masterpieces_derivatives';
  static const audioFolder = 'audio';
}
