class WorksheetModel {
  final String name;
  final String? worksheet; // Base64 PDF
  final String? worksheetType; // 'pdf', 'text', 'google_slide'
  final String? worksheetGoogleSlide;
  final String? operationNote; // HTML content
  final int? operationId;
  final String? operationName;

  WorksheetModel({
    required this.name,
    this.worksheet,
    this.worksheetType,
    this.worksheetGoogleSlide,
    this.operationNote,
    this.operationId,
    this.operationName,
  });

  factory WorksheetModel.fromJson(Map<String, dynamic> json) {
    final operationData = json['operation_id'];
    int? operationId;
    String? operationName;
    if (operationData != null && operationData != false) {
      if (operationData is List) {
        operationId = operationData[0];
        operationName = operationData[1];
      } else {
        operationId = operationData;
      }
    }

    return WorksheetModel(
      name: json['name'] ?? '',
      worksheet: json['worksheet'] != false ? json['worksheet'] : null,
      worksheetType: json['worksheet_type'] ?? '',
      worksheetGoogleSlide: json['worksheet_google_slide'] != false ? json['worksheet_google_slide'] : null,
      operationNote: json['operation_note'] != false ? json['operation_note'] : null,
      operationId: operationId,
      operationName: operationName,
    );
  }

  bool get hasContent {
    return (worksheetType == 'pdf' && worksheet != null) ||
        (worksheetType == 'text' && operationNote != null) ||
        (worksheetType == 'google_slide' && worksheetGoogleSlide != null);
  }
}
