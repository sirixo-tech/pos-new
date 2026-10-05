const menuImportMimeTypes = <String, String>{
  'csv': 'text/csv',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'gif': 'image/gif',
  'pdf': 'application/pdf',
};

bool acceptsMenuImportFile(String filename, Iterable<String> accepted) {
  final extension = filename.split('.').last.trim().toLowerCase();
  final types = accepted.map((type) => type.trim().toLowerCase()).toSet();
  if (types.isEmpty) return true;
  final mime = menuImportMimeTypes[extension];
  final aliases = extension == 'jpg' || extension == 'jpeg'
      ? {'jpg', 'jpeg'} : {extension};
  return aliases.any((ext) => types.contains(ext) || types.contains('.$ext')) ||
      (mime != null && types.contains(mime));
}
