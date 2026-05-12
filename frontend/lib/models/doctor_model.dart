class DoctorModel {
  final String id;
  final String specialization;
  final String city;
  final String consultationType;
  final int experienceYears;
  final int consultationFee;
  final String bio;
  final String? profilePictureUrl;
  final double rating;
  final int reviewCount;
  final String pmdcNumber;
  final String verificationStatus;
  final bool isAvailable;

  DoctorModel({
    required this.id,
    required this.specialization,
    required this.city,
    required this.consultationType,
    required this.experienceYears,
    required this.consultationFee,
    required this.bio,
    this.profilePictureUrl,
    required this.rating,
    required this.reviewCount,
    required this.pmdcNumber,
    required this.verificationStatus,
    required this.isAvailable,
  });

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    return DoctorModel(
      id: json['id'],
      specialization: json['specialization'],
      city: json['city'],
      consultationType: json['consultation_type'],
      experienceYears: json['experience_years'],
      consultationFee: json['consultation_fee'],
      bio: json['bio'] ?? '',
      profilePictureUrl: json['profile_picture_url'],
      rating: (json['rating'] ?? 0.0).toDouble(),
      reviewCount: json['review_count'] ?? 0,
      pmdcNumber: json['pmdc_number'] ?? '',
      verificationStatus: json['verification_status'],
      isAvailable: json['is_available'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'specialization': specialization,
      'city': city,
      'consultation_type': consultationType,
      'experience_years': experienceYears,
      'consultation_fee': consultationFee,
      'bio': bio,
      'profile_picture_url': profilePictureUrl,
      'rating': rating,
      'review_count': reviewCount,
      'pmdc_number': pmdcNumber,
      'verification_status': verificationStatus,
      'is_available': isAvailable,
    };
  }

  DoctorModel copyWith({
    String? id,
    String? specialization,
    String? city,
    String? consultationType,
    int? experienceYears,
    int? consultationFee,
    String? bio,
    String? profilePictureUrl,
    double? rating,
    int? reviewCount,
    String? pmdcNumber,
    String? verificationStatus,
    bool? isAvailable,
  }) {
    return DoctorModel(
      id: id ?? this.id,
      specialization: specialization ?? this.specialization,
      city: city ?? this.city,
      consultationType: consultationType ?? this.consultationType,
      experienceYears: experienceYears ?? this.experienceYears,
      consultationFee: consultationFee ?? this.consultationFee,
      bio: bio ?? this.bio,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      pmdcNumber: pmdcNumber ?? this.pmdcNumber,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}
