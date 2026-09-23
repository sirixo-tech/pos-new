/// Resolve a storage path or absolute URL to a fetchable media URL.
///
/// API payloads may still return relative storage paths (e.g. `restaurants/logos/x.png`).
/// Flutter network images require an absolute URL with host.
String? resolveMediaUrl(String? path, {String? serverUrl}) {
  if (path == null) return null;
  final trimmed = path.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }

  final base = serverUrl?.trim();
  if (base == null || base.isEmpty) return null;

  var origin = base;
  while (origin.endsWith('/')) {
    origin = origin.substring(0, origin.length - 1);
  }

  var clean = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
  if (clean.startsWith('storage/')) {
    clean = clean.substring('storage/'.length);
  }
  if (clean.startsWith('media/')) {
    return '$origin/$clean';
  }

  return '$origin/media/$clean';
}
