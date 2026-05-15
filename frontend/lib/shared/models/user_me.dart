class UserMeModel {
  UserMeModel({
    required this.email,
    this.displayName,
    this.manualMapLat,
    this.manualMapLng,
    required this.travelerType,
    required this.isAdmin,
    required this.acceptedResearchConsent,
  });

  final String email;
  final String? displayName;
  final double? manualMapLat;
  final double? manualMapLng;
  final String travelerType;
  final bool isAdmin;
  final bool acceptedResearchConsent;

  factory UserMeModel.fromJson(Map<String, dynamic> json) {
    return UserMeModel(
      email: (json['email'] ?? '').toString(),
      displayName: json['display_name'] as String?,
      manualMapLat: (json['manual_map_lat'] as num?)?.toDouble(),
      manualMapLng: (json['manual_map_lng'] as num?)?.toDouble(),
      travelerType: (json['traveler_type'] ?? 'mixed').toString(),
      isAdmin: json['is_admin'] == true,
      acceptedResearchConsent: json['accepted_research_consent'] == true,
    );
  }
}
