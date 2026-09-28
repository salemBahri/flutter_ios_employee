import 'package:flutter/material.dart';
import '../utils/app_localizations.dart';

class ComponentModel {
  final int id;
  final String name;
  final int productId;
  final String productName;
  final double productUomQty;
  final double reservedAvailability;
  final double quantityDone;
  final String state;
  final int? operationId;
  final String? operationName;
  final int productionId;
  final Map<String, dynamic>? productImageBase64; // ⭐ صور Base64

  ComponentModel({
    required this.id,
    required this.name,
    required this.productId,
    required this.productName,
    required this.productUomQty,
    required this.reservedAvailability,
    required this.quantityDone,
    required this.state,
    this.operationId,
    this.operationName,
    required this.productionId,
    this.productImageBase64, // ⭐
  });

  factory ComponentModel.fromJson(Map<String, dynamic> json) {
    final productData = json['product_id'];
    final productId = productData is List ? productData[0] : productData;
    final productName = productData is List ? productData[1] : json['name'] ?? '';

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

    final productionData = json['raw_material_production_id'];
    final productionId = productionData is List ? productionData[0] : productionData;

    return ComponentModel(
      id: json['id'],
      name: json['name'] ?? '',
      productId: productId,
      productName: productName,
      productUomQty: (json['product_uom_qty'] ?? 0).toDouble(),
      reservedAvailability: (json['reserved_availability'] ?? 0).toDouble(),
      quantityDone: (json['quantity_done'] ?? 0).toDouble(),
      state: json['state'] ?? '',
      operationId: operationId,
      operationName: operationName,
      productionId: productionId,
      productImageBase64: json['product_image_base64'], // ⭐
    );
  }

  double get progressPercentage {
    if (productUomQty == 0) return 0;
    return (quantityDone / productUomQty * 100).clamp(0, 100);
  }

  bool get isComplete => quantityDone >= productUomQty;

  Color getStateColor() {
    switch (state) {
      case 'draft':
        return Colors.grey;
      case 'waiting':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'assigned':
        return Colors.green;
      case 'done':
        return Colors.teal;
      case 'cancel':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String getStateLabel(AppLocalizations localizations) {
    switch (state) {
      case 'draft':
        return localizations.translate('draft');
      case 'waiting':
        return localizations.translate('waiting');
      case 'confirmed':
        return localizations.translate('confirmed');
      case 'assigned':
        return localizations.translate('assigned');
      case 'done':
        return localizations.translate('done');
      case 'cancel':
        return localizations.translate('cancelled');
      default:
        return state;
    }
  }
}
