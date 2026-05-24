class UserModel {
  final String id;
  final String? phone;
  final String? name;
  final String? gender;
  final String? bloodGroup;
  final String? medicalNote;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    this.phone,
    this.name,
    this.gender,
    this.bloodGroup,
    this.medicalNote,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      phone: json['phone'] as String?,
      name: json['name'] as String?,
      gender: json['gender'] as String?,
      bloodGroup: json['bloodGroup'] as String?,
      medicalNote: json['medicalNote'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (phone != null) 'phone': phone,
      if (name != null) 'name': name,
      if (gender != null) 'gender': gender,
      if (bloodGroup != null) 'bloodGroup': bloodGroup,
      if (medicalNote != null) 'medicalNote': medicalNote,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? phone,
    String? name,
    String? gender,
    String? bloodGroup,
    String? medicalNote,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      medicalNote: medicalNote ?? this.medicalNote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
