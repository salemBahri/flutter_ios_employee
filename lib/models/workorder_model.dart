class WorkOrderModel {
  final int id;
  final String name;
  final String state;
  final String? productionState;
  final String? workingState;
  final bool isUserWorking;
  final String? datePlannedStart;
  final String? datePlannedFinished;

  final String? operationName;
  final double? durationExpected;
  final double? duration;

  final int? sequence; // ⭐ ترتيب العملية ضمن مسار التصنيع (routing)

  final int? workcenterId;
  final String? workcenterName;

  final int? companyId;
  final String? companyName;

  final int? productionId;
  final String? productionName;

  final int? productId;
  final String? productName;

  final bool isUrgent;

  final int? productionUserId;
  final String? productionUserName;

  WorkOrderModel({
    required this.id,
    required this.name,
    required this.state,
    required this.isUserWorking,
    this.productionState,
    this.workingState,
    this.datePlannedStart,
    this.datePlannedFinished,
    this.workcenterId,
    this.workcenterName,
    this.companyId,
    this.companyName,
    this.productionId,
    this.productionName,
    this.productId,
    this.productName,
    this.isUrgent = false,
    this.operationName,
    this.durationExpected,
    this.duration,
    this.sequence,
    this.productionUserId,
    this.productionUserName,
  });

  factory WorkOrderModel.fromJson(Map<String, dynamic> json, {bool isUrgent = false}) {
    String? operationName;
    if (json['operation_id'] != null && json['operation_id'] is List) {
      final operationList = json['operation_id'] as List;
      if (operationList.length > 1) {
        operationName = operationList[1]?.toString();
      }
    }

    double? durationExpected;
    if (json['duration_expected'] != null) {
      durationExpected = (json['duration_expected'] as num).toDouble();
    }

    double? duration;
    if (json['duration'] != null) {
      duration = (json['duration'] as num).toDouble();
    }

    int? sequence;
    if (json['sequence'] != null && json['sequence'] != false) {
      sequence = (json['sequence'] as num).toInt();
    }

    return WorkOrderModel(
      id: json['id'],
      name: json['name'] ?? '',
      state: json['state'] ?? '',
      productionState: json['production_state']?.toString(),
      workingState: json['working_state']?.toString(),
      isUserWorking: json['is_user_working'] ?? false,
      datePlannedStart: json['date_planned_start']?.toString(),
      datePlannedFinished: json['date_planned_finished']?.toString(),

      workcenterId: _extractId(json['workcenter_id']),
      workcenterName: _extractName(json['workcenter_id']),

      companyId: _extractId(json['company_id']),
      companyName: _extractName(json['company_id']),

      productionId: _extractId(json['production_id']),
      productionName: _extractName(json['production_id']),

      productId: _extractId(json['product_id']),
      productName: _extractName(json['product_id']),

      isUrgent: isUrgent,

      operationName: operationName,
      durationExpected: durationExpected,
      duration: duration,
      sequence: sequence,

      productionUserId: json['production_user_id'] is int
          ? json['production_user_id'] as int
          : null,
      productionUserName: json['production_user_name']?.toString(),
    );
  }

  static int? _extractId(dynamic field) {
    if (field is List && field.isNotEmpty) {
      return field[0] as int?;
    }
    return null;
  }

  static String? _extractName(dynamic field) {
    if (field is List && field.length > 1) {
      return field[1]?.toString();
    }
    return null;
  }

  WorkOrderStatus get customStatus {
    if (state == 'waiting') {
      return WorkOrderStatus.waiting;
    }

    if (workingState == 'blocked') {
      return WorkOrderStatus.blocked;
    }

    if (state == 'pending') {
      return WorkOrderStatus.pending;
    }

    if (state == 'progress' && isUserWorking && workingState == 'done') {
      return WorkOrderStatus.inProgress;
    }

    if (state == 'progress' && !isUserWorking) {
      return WorkOrderStatus.paused;
    }

    return WorkOrderStatus.waiting;
  }

  bool get isDone => state == 'done';

  bool get hasProductionUser => productionUserId != null;
}

enum WorkOrderStatus {
  waiting,
  blocked,
  pending,
  inProgress,
  paused,
}
