class DatabaseModel {
  final String name;

  DatabaseModel({required this.name});

  factory DatabaseModel.fromString(String name) {
    return DatabaseModel(name: name);
  }
}
