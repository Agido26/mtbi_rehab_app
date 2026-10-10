class Patient {
  final String id;
  final String username;
  final DateTime createdAt;
  final DateTime lastLogin;
  final String? doctorId; // ✅ الطبيب المتابع (null للمرضى القدامى قبل التبني)

  Patient({
    required this.id,
    required this.username,
    required this.createdAt,
    required this.lastLogin,
    this.doctorId,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] as String,
      username: json['username'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLogin: DateTime.parse(json['lastLogin'] as String),
      doctorId: json['doctorId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin.toIso8601String(),
      'doctorId': doctorId,
    };
  }

  Patient copyWith({
    String? id,
    String? username,
    DateTime? createdAt,
    DateTime? lastLogin,
    String? doctorId,
  }) {
    return Patient(
      id: id ?? this.id,
      username: username ?? this.username,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      doctorId: doctorId ?? this.doctorId,
    );
  }
}
