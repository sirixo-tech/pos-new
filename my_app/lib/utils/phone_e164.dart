class PhoneCountry {
  const PhoneCountry({
    required this.iso,
    required this.dial,
    required this.name,
  });

  final String iso;
  final String dial;
  final String name;
}

const kPhoneCountries = <PhoneCountry>[
  PhoneCountry(iso: 'IN', dial: '+91', name: 'India'),
  PhoneCountry(iso: 'US', dial: '+1', name: 'United States'),
  PhoneCountry(iso: 'CA', dial: '+1', name: 'Canada'),
  PhoneCountry(iso: 'GB', dial: '+44', name: 'United Kingdom'),
  PhoneCountry(iso: 'AE', dial: '+971', name: 'United Arab Emirates'),
  PhoneCountry(iso: 'SA', dial: '+966', name: 'Saudi Arabia'),
  PhoneCountry(iso: 'QA', dial: '+974', name: 'Qatar'),
  PhoneCountry(iso: 'KW', dial: '+965', name: 'Kuwait'),
  PhoneCountry(iso: 'OM', dial: '+968', name: 'Oman'),
  PhoneCountry(iso: 'SG', dial: '+65', name: 'Singapore'),
  PhoneCountry(iso: 'MY', dial: '+60', name: 'Malaysia'),
  PhoneCountry(iso: 'AU', dial: '+61', name: 'Australia'),
  PhoneCountry(iso: 'NP', dial: '+977', name: 'Nepal'),
  PhoneCountry(iso: 'BD', dial: '+880', name: 'Bangladesh'),
  PhoneCountry(iso: 'LK', dial: '+94', name: 'Sri Lanka'),
];

PhoneCountry phoneCountryByIso(String iso) {
  final key = iso.trim().toUpperCase();
  for (final country in kPhoneCountries) {
    if (country.iso == key) return country;
  }
  return kPhoneCountries.first;
}

/// Returns E.164 (`+919876543210`) or null when the number cannot be valid.
String? toE164(String iso, String national) {
  var raw = national.trim().replaceAll(RegExp(r'[\s\-().]'), '');
  if (raw.isEmpty) return null;
  if (raw.startsWith('+')) {
    final digits = raw.substring(1);
    if (!RegExp(r'^\d{8,15}$').hasMatch(digits)) return null;
    return '+$digits';
  }
  if (raw.startsWith('00')) raw = raw.substring(2);
  final dial = phoneCountryByIso(iso).dial.replaceFirst('+', '');
  if (raw.startsWith(dial) && raw.length >= dial.length + 8) {
    // National entry already includes the country code, without a plus.
  } else {
    raw = raw.replaceFirst(RegExp(r'^0+'), '');
    raw = '$dial$raw';
  }
  if (!RegExp(r'^\d{8,15}$').hasMatch(raw)) return null;
  return '+$raw';
}
