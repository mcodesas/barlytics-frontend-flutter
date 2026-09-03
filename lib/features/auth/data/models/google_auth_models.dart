class GoogleAuthConfigModel {
  const GoogleAuthConfigModel({
    required this.enabled,
    this.webClientId,
    this.iosClientId,
    this.desktopClientId,
  });

  final bool enabled;
  final String? webClientId;
  final String? iosClientId;
  final String? desktopClientId;

  factory GoogleAuthConfigModel.fromJson(Map<String, dynamic> json) => GoogleAuthConfigModel(
        enabled: json['enabled'] == true,
        webClientId: json['webClientId']?.toString(),
        iosClientId: json['iosClientId']?.toString(),
        desktopClientId: json['desktopClientId']?.toString(),
      );
}

class GoogleIdentityModel {
  const GoogleIdentityModel({
    required this.email,
    required this.emailVerified,
    required this.accountExists,
    this.givenName,
    this.familyName,
    this.displayName,
    this.pictureUrl,
  });

  final String email;
  final bool emailVerified;
  final bool accountExists;
  final String? givenName;
  final String? familyName;
  final String? displayName;
  final String? pictureUrl;

  factory GoogleIdentityModel.fromJson(Map<String, dynamic> json) => GoogleIdentityModel(
        email: json['email']?.toString() ?? '',
        emailVerified: json['emailVerified'] == true,
        accountExists: json['accountExists'] == true,
        givenName: json['givenName']?.toString(),
        familyName: json['familyName']?.toString(),
        displayName: json['displayName']?.toString(),
        pictureUrl: json['pictureUrl']?.toString(),
      );
}
