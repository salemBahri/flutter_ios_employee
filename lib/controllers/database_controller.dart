import 'package:flutter/material.dart';
import '../services/odoo_service.dart';
import '../models/database_model.dart';

class DatabaseController extends ChangeNotifier {
  final OdooService _odooService = OdooService();

  List<DatabaseModel> _databases = [];
  bool _isLoading = false;
  String? _error;

  List<DatabaseModel> get databases => _databases;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadDatabases() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final dbList = await _odooService.getDatabases();
      _databases = dbList.map((db) => DatabaseModel.fromString(db)).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
