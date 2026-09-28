class UserModel {
  final int userId;
  final String username;
  final String database;
  final String sessionId;

  UserModel({
    required this.userId,
    required this.username,
    required this.database,
    required this.sessionId,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'database': database,
      'sessionId': sessionId,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'],
      username: json['username'],
      database: json['database'],
      sessionId: json['sessionId'],
    );
  }
}
