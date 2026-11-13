String? validateClientFullName(String? value) {
  final name = value?.trim() ?? '';
  if (name.length < 2) {
    return 'Saisissez un nom d’au moins 2 caractères.';
  }
  if (name.length > 80) {
    return 'Le nom ne peut pas dépasser 80 caractères.';
  }
  return null;
}

String? validateClientEmail(String? value) {
  final email = value?.trim() ?? '';
  if (!RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
      .hasMatch(email)) {
    return 'Saisissez une adresse e-mail valide.';
  }
  return null;
}

String? validateClientPhone(String? value) {
  final phone = value?.trim() ?? '';
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (!RegExp(r'^[+()\d.\-\s]+$').hasMatch(phone) ||
      digits.length < 7 ||
      digits.length > 15) {
    return 'Saisissez un numéro contenant 7 à 15 chiffres.';
  }
  return null;
}

String? validateClientPassword(String? value) {
  if ((value ?? '').length < 6) {
    return 'Le mot de passe doit contenir au moins 6 caractères.';
  }
  return null;
}

String? validateDriverLicenseNumber(String? value) {
  if ((value ?? '').trim().length > 100) {
    return 'Le numéro de permis ne peut pas dépasser 100 caractères.';
  }
  return null;
}
