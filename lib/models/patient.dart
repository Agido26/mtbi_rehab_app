class Patient {
  final String id;
  final String username;
  final DateTime createdAt;
  final DateTime lastLogin;

  Patient({
    required this.id,
    required this.username,
    required this.createdAt,
    required this.lastLogin,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] as String,
      username: json['username'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLogin: DateTime.parse(json['lastLogin'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin.toIso8601String(),
    };
  }

  Patient copyWith({
    String? id,
    String? username,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return Patient(
      id: id ?? this.id,
      username: username ?? this.username,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}
