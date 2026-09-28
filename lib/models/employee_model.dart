class EmployeeModel {
  final int id;
  final String name;
  final int? departmentId;
  final String? departmentName;

  EmployeeModel({
    required this.id,
    required this.name,
    this.departmentId,
    this.departmentName,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    // department_id يأتي كـ [id, "name"] أو false
    int? deptId;
    String? deptName;

    if (json['department_id'] != null && json['department_id'] != false) {
      if (json['department_id'] is List) {
        deptId = json['department_id'][0];
        deptName = json['department_id'][1];
      }
    }

    return EmployeeModel(
      id: json['id'],
      name: json['name'],
      departmentId: deptId,
      departmentName: deptName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'departmentId': departmentId,
      'departmentName': departmentName,
    };
  }
}
