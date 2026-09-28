import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/workorder_model.dart';
import '../services/odoo_service.dart';
import '../services/notification_service.dart';
import '../services/notification_db_helper.dart';
import '../utils/app_localizations.dart';
import '../utils/shared_prefs_helper.dart';
import '../controllers/language_controller.dart';
import '../controllers/auth_controller.dart';
import 'login_view.dart';
import 'components_view.dart';
import 'worksheet_view.dart';

class WorkOrderDetailsView extends StatefulWidget {
  final WorkOrderModel workOrder;

  const WorkOrderDetailsView({Key? key, required this.workOrder}) : super(key: key);

  @override
  State<WorkOrderDetailsView> createState() => _WorkOrderDetailsViewState();
}

class _WorkOrderDetailsViewState extends State<WorkOrderDetailsView> {
  final OdooService _odooService = OdooService();
  final NotificationService _notificationService = NotificationService();
  final NotificationDbHelper _notificationDb = NotificationDbHelper();
  bool _isLoading = false;

  late WorkOrderModel _currentWorkOrder;
  late Duration _selectedCncDuration;

  @override
  void initState() {
    super.initState();
    _currentWorkOrder = widget.workOrder;
    _selectedCncDuration = _minutesToDuration(_currentWorkOrder.duration);
  }

  // ⭐ تحديد إذا كانت هذه عملية CNC (بناءً على اسم العملية أو مركز العمل)
  bool get _isCncOperation {
    final opName = (_currentWorkOrder.operationName ?? '').toUpperCase();
    final wcName = (_currentWorkOrder.workcenterName ?? '').toUpperCase();
    return opName.contains('CNC') || wcName.contains('CNC');
  }

  Duration _minutesToDuration(double? minutes) {
    if (minutes == null || minutes <= 0) return Duration.zero;
    final totalSeconds = (minutes * 60).round();
    return Duration(seconds: totalSeconds);
  }

  double _durationToMinutes(Duration d) => d.inSeconds / 60.0;

  String _formatMinutesSecondsLabel(Duration d) {
    final totalMinutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$totalMinutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _refreshWorkOrder() async {
    setState(() => _isLoading = true);
    try {
      final userData = SharedPrefsHelper.getUserData();
      final employeeId = userData!['employeeId'] as int;

      final workOrders = await _odooService.fetchWorkOrders(
        database: userData['database'],
        userId: userData['userId'],
        password: userData['password'],
        employeeId: employeeId,
      );

      final updatedWO = workOrders.firstWhere(
            (wo) => wo['id'] == _currentWorkOrder.id,
        orElse: () => {},
      );

      if (updatedWO.isNotEmpty) {
        setState(() {
          _currentWorkOrder = WorkOrderModel.fromJson(updatedWO);
          _selectedCncDuration = _minutesToDuration(_currentWorkOrder.duration);
        });
      }
    } catch (e) {
      print('Error refreshing: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final languageController = Provider.of<LanguageController>(context);
    final authController = Provider.of<AuthController>(context);
    final userData = SharedPrefsHelper.getUserData();

    final employeeName = authController.currentEmployee?.name ??
        authController.currentUser?.username ??
        userData?['employeeName'] ??
        'User';
    final departmentName = authController.currentEmployee?.departmentName ??
        userData?['departmentName'] ?? '';

    final statusInfo = _getStatusInfo(_currentWorkOrder.customStatus, localizations);
    final statusColor = statusInfo['color'] as Color;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _buildAppBar(employeeName, departmentName, languageController, authController, localizations),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshWorkOrder,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildStatusBadge(statusInfo, statusColor, localizations),
                  const SizedBox(height: 12),
                  _buildManufacturingOrder(),
                  const SizedBox(height: 10),
                  _buildProductName(),
                  const SizedBox(height: 10),
                  _buildDatesRow(localizations),
                  const SizedBox(height: 10),
                  _buildOperationWorkCenterRow(localizations),
                  const SizedBox(height: 12),
                  if (_currentWorkOrder.durationExpected != null || _currentWorkOrder.duration != null) ...[
                    _buildDurationCard(localizations),
                    const SizedBox(height: 12),
                  ],
                  // ⭐ إذا كانت عملية CNC: إدخال يدوي للمدة فقط - بدون أزرار Start/Pause/Block
                  _isCncOperation
                      ? _buildCncDurationInput(localizations)
                      : _buildActionButtons(localizations),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      String employeeName,
      String departmentName,
      LanguageController languageController,
      AuthController authController,
      AppLocalizations localizations,
      ) {
    return AppBar(
      backgroundColor: const Color(0xFF455A64),
      elevation: 0,
      toolbarHeight: 70,
      leading: IconButton(
        onPressed: () => Navigator.pop(context, true),
        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
      ),
      title: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            ),
            child: Center(
              child: Text(
                employeeName.isNotEmpty ? employeeName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  employeeName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (departmentName.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Text(
                      departmentName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.language, color: Colors.white, size: 24),
          tooltip: localizations.translate('change_language'),
          onPressed: () => _showLanguageDialog(context, languageController, localizations),
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white, size: 24),
          tooltip: localizations.translate('logout'),
          onPressed: () => _showLogoutDialog(context, authController, localizations),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildStatusBadge(Map<String, dynamic> statusInfo, Color statusColor, AppLocalizations localizations) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getStatusIcon(_currentWorkOrder.customStatus),
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            statusInfo['label'],
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManufacturingOrder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Text(
        _currentWorkOrder.productionName ?? '--',
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildProductName() {
    final cleanProductName = _cleanProductName(_currentWorkOrder.productName);

    if (cleanProductName == null || cleanProductName.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Text(
        cleanProductName,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDatesRow(AppLocalizations localizations) {
    final isDatesScheduled = _isDateScheduled(_currentWorkOrder.datePlannedStart);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: isDatesScheduled
          ? Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.play_circle_outline, size: 14, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      localizations.translate('date_start'),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _formatDate(_currentWorkOrder.datePlannedStart),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 35,
            color: Colors.grey[300],
            margin: const EdgeInsets.symmetric(horizontal: 6),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.flag_outlined, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      localizations.translate('date_end'),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _formatDate(_currentWorkOrder.datePlannedFinished),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      )
          : Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule_outlined, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(
            localizations.translate('not_scheduled'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationWorkCenterRow(AppLocalizations localizations) {
    final hasOperation = _currentWorkOrder.operationName != null;
    final hasWorkcenter = _currentWorkOrder.workcenterName != null;

    if (!hasOperation && !hasWorkcenter) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              if (hasOperation)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.build_outlined, size: 14, color: Colors.indigo),
                          const SizedBox(width: 4),
                          Text(
                            localizations.translate('operation'),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _currentWorkOrder.operationName!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              if (hasOperation && hasWorkcenter)
                Container(
                  width: 1,
                  height: 35,
                  color: Colors.grey[300],
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                ),
              if (hasWorkcenter)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.factory_outlined, size: 14, color: Colors.teal),
                          const SizedBox(width: 4),
                          Text(
                            localizations.translate('workcenter'),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _currentWorkOrder.workcenterName!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (_currentWorkOrder.productionId != null && _currentWorkOrder.workcenterId != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ComponentsView(
                      productionId: _currentWorkOrder.productionId!,
                      workcenterId: _currentWorkOrder.workcenterId!,
                      productionName: _currentWorkOrder.productionName ?? '',
                      workorderName: _currentWorkOrder.name ?? '',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.inventory_2_outlined, size: 18),
              label: Text(
                localizations.translate('view_components'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WorksheetView(
                    workOrderId: _currentWorkOrder.id,
                    workOrderName: _currentWorkOrder.name,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.description_outlined, size: 18),
            label: Text(
              localizations.translate('work_instructions'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: const BorderSide(color: Colors.green, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationCard(AppLocalizations localizations) {
    final expected = _currentWorkOrder.durationExpected ?? 0;
    final actual = _currentWorkOrder.duration ?? 0;
    final progress = expected > 0 ? (actual / expected).clamp(0.0, 1.0) : 0.0;
    final percentage = (progress * 100).toInt();

    Color progressColor;
    if (percentage <= 70) {
      progressColor = Colors.green;
    } else if (percentage <= 90) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.red;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: progressColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.timer_outlined, color: progressColor, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  localizations.translate('duration'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatDuration(actual)} / ${_formatDuration(expected)}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: progressColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: progressColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    '$percentage%',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: progressColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDurationInfo(
                    icon: Icons.access_time,
                    label: localizations.translate('expected'),
                    value: _formatDuration(expected),
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildDurationInfo(
                    icon: Icons.schedule,
                    label: localizations.translate('actual'),
                    value: _formatDuration(actual),
                    color: progressColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationInfo({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 8, color: Colors.grey[600])),
          const SizedBox(height: 1),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // ⭐ إدخال يدوي للمدة (CNC فقط) - Wheel Picker حقيقي بدل نص حر
  Widget _buildCncDurationInput(AppLocalizations localizations) {
    final previewText = _formatMinutesSecondsLabel(_selectedCncDuration);
    final status = _currentWorkOrder.customStatus;
    final isBlocked = status == WorkOrderStatus.blocked;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.precision_manufacturing_rounded, color: Colors.indigo, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    localizations.translate('cnc_manual_duration_title'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              localizations.translate('cnc_manual_duration_subtitle'),
              style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.3),
            ),
            const SizedBox(height: 12),

            // ⭐ Wheel Picker: ساعات / دقائق / ثواني
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SizedBox(
                height: 180,
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.hms,
                  initialTimerDuration: _selectedCncDuration,
                  onTimerDurationChanged: (Duration newDuration) {
                    setState(() => _selectedCncDuration = newDuration);
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ⭐ معاينة القيمة بصيغة دقائق:ثواني
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.indigo.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 18, color: Colors.indigo),
                  const SizedBox(width: 8),
                  Text(
                    localizations.translate('duration_minutes'),
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  const Spacer(),
                  Text(
                    previewText,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ⭐ 1. حفظ المدة
            _buildButton(
              label: localizations.translate('save'),
              icon: Icons.save_rounded,
              color: Colors.indigo,
              onPressed: _handleUpdateCncDuration,
            ),

            const SizedBox(height: 10),

            // ⭐ 3. إنهاء (يفتح نافذة "اكتب OK للتأكيد")
            _buildButton(
              label: localizations.translate('terminate'),
              icon: Icons.check_circle_rounded,
              color: Colors.green,
              onPressed: _handleTerminate,
            ),

            const SizedBox(height: 10),

            // ⭐ 2. حظر / إلغاء حظر (حسب الحالة الحالية)
            isBlocked
                ? _buildButton(
              label: localizations.translate('unblock'),
              icon: Icons.lock_open,
              color: Colors.green,
              onPressed: _handleUnblock,
            )
                : _buildButton(
              label: localizations.translate('block'),
              icon: Icons.block,
              color: Colors.red,
              onPressed: _handleBlock,
              isOutlined: true,
            ),


          ],
        ),
      ),
    );
  }

  Future<void> _handleUpdateCncDuration() async {
    final localizations = AppLocalizations.of(context);

    if (_selectedCncDuration.inSeconds <= 0) {
      _showError(localizations.translate('invalid_duration'));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userData = SharedPrefsHelper.getUserData();
      final decimalMinutes = _durationToMinutes(_selectedCncDuration);

      await _odooService.updateWorkOrderDuration(
        database: userData!['database'],
        userId: userData['userId'],
        password: userData['password'],
        workOrderId: _currentWorkOrder.id,
        durationMinutes: decimalMinutes,
      );
      _showSuccess(localizations.translate('duration_updated'));
      await _refreshWorkOrder();
      await _checkAndNotifyDurationExceeded();
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildActionButtons(AppLocalizations localizations) {
    final status = _currentWorkOrder.customStatus;

    return Column(
      children: [
        if (status == WorkOrderStatus.waiting) ...[
          _buildButton(
            label: localizations.translate('start'),
            icon: Icons.play_arrow_rounded,
            color: Colors.green,
            onPressed: _handleStart,
          ),
          const SizedBox(height: 10),
          _buildButton(
            label: localizations.translate('block'),
            icon: Icons.block,
            color: Colors.red,
            onPressed: _handleBlock,
            isOutlined: true,
          ),
        ],
        if (status == WorkOrderStatus.blocked)
          _buildButton(
            label: localizations.translate('unblock'),
            icon: Icons.lock_open,
            color: Colors.green,
            onPressed: _handleUnblock,
          ),
        if (status == WorkOrderStatus.pending) ...[
          _buildButton(
            label: localizations.translate('start'),
            icon: Icons.play_arrow_rounded,
            color: Colors.green,
            onPressed: _handleStart,
          ),
          const SizedBox(height: 10),
          _buildButton(
            label: localizations.translate('block'),
            icon: Icons.block,
            color: Colors.red,
            onPressed: _handleBlock,
            isOutlined: true,
          ),
        ],
        if (status == WorkOrderStatus.inProgress) ...[
          _buildButton(
            label: localizations.translate('pause'),
            icon: Icons.pause_rounded,
            color: Colors.orange,
            onPressed: _showPauseReasonDialog,
          ),
          const SizedBox(height: 10),
          _buildButton(
            label: localizations.translate('block'),
            icon: Icons.block,
            color: Colors.red,
            onPressed: _handleBlock,
            isOutlined: true,
          ),
        ],
        if (status == WorkOrderStatus.paused) ...[
          _buildButton(
            label: localizations.translate('resume'),
            icon: Icons.play_arrow_rounded,
            color: Colors.blue,
            onPressed: _handleStart,
          ),
          const SizedBox(height: 10),
          _buildButton(
            label: localizations.translate('terminate'),
            icon: Icons.check_circle_rounded,
            color: Colors.green,
            onPressed: _handleTerminate,
          ),
          const SizedBox(height: 10),
          _buildButton(
            label: localizations.translate('block'),
            icon: Icons.block,
            color: Colors.red,
            onPressed: _handleBlock,
            isOutlined: true,
          ),
        ],
      ],
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isOutlined = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: isOutlined
          ? OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      )
          : ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  // ⭐ فحص تجاوز المدة المتوقعة + إرسال إشعار يصل في كل مرة (بدون منع تكرار)
  Future<void> _checkAndNotifyDurationExceeded() async {
    print('🔔 [NOTIF] ▶️ _checkAndNotifyDurationExceeded() بدأ للـ workorder ${_currentWorkOrder.id}');
    print('🔔 [NOTIF]    duration = ${_currentWorkOrder.duration}');
    print('🔔 [NOTIF]    durationExpected = ${_currentWorkOrder.durationExpected}');

    if (_currentWorkOrder.duration == null ||
        _currentWorkOrder.durationExpected == null ||
        _currentWorkOrder.durationExpected! <= 0 ||
        _currentWorkOrder.duration! <= _currentWorkOrder.durationExpected!) {
      print('🔔 [NOTIF] ⛔ توقف: الشرط لم يتحقق (duration <= durationExpected أو قيم null/صفر)');
      return;
    }

    print('🔔 [NOTIF] ✅ الشرط تحقق: duration > durationExpected');

    final userData = SharedPrefsHelper.getUserData();
    final userId = userData?['userId'] as int?;
    final employeeName = userData?['employeeName'] as String? ?? '';
    if (userId == null) {
      print('🔔 [NOTIF] ⛔ توقف: userId غير موجود');
      return;
    }

    final langCode = Provider.of<LanguageController>(context, listen: false).locale.languageCode;
    final title = AppLocalizations.translateFor(langCode, 'notif_duration_exceeded_title');

    final cleanedProduct = _cleanProductName(_currentWorkOrder.productName);
    final productDisplay = (cleanedProduct != null && cleanedProduct.isNotEmpty)
        ? cleanedProduct
        : _currentWorkOrder.name;

    final template = AppLocalizations.translateFor(langCode, 'notif_duration_exceeded_message');

    final htmlMessage = template
        .replaceAll('{name}', '🔴 $employeeName 🔴')
        .replaceAll('{product}', '🔴 $productDisplay 🔴')
        .replaceAll('\n', '');
    final htmlBody = '$htmlMessage';

    final plainBody = template
        .replaceAll('{name}', employeeName)
        .replaceAll('{product}', productDisplay);

    print('🔔 [NOTIF] 📤 استدعاء NotificationService.show() -> title="$title" body="$plainBody"');

    await _notificationService.show(
      id: _currentWorkOrder.id * 10 + 2,
      title: title,
      body: htmlBody,
      payload: 'workorder_${_currentWorkOrder.id}',
      isHtml: true,
    );

    print('🔔 [NOTIF] ✅ تم استدعاء show() بنجاح');

    await _notificationDb.insertNotification(
      userId: userId,
      workorderId: _currentWorkOrder.id,
      type: 'duration_exceeded',
      title: title,
      body: plainBody,
      language: langCode,
      highlight1: employeeName,
      highlight2: productDisplay,
    );

    print('🔔 [NOTIF] 💾 تم حفظ الإشعار في SQLite');
  }

  // ⭐ نقطة الدخول لـ Start/Resume: تفحص التسلسل أولاً إذا كانت الحالة pending أو waiting
  Future<void> _handleStart() async {
    final status = _currentWorkOrder.customStatus;

    if (status == WorkOrderStatus.pending || status == WorkOrderStatus.waiting) {
      final canProceed = await _checkPriorOperationsAndConfirm();
      if (!canProceed) return;
    }

    await _performStart();
  }

  // ⭐ يجيب أوامر العمل التابعة لنفس أمر التصنيع، ويفلتر اللي ترتيبها (sequence) أقل من الحالي
  Future<bool> _checkPriorOperationsAndConfirm() async {
    if (_currentWorkOrder.productionId == null || _currentWorkOrder.sequence == null) {
      return true;
    }

    setState(() => _isLoading = true);
    List<Map<String, dynamic>> priorOps = [];

    try {
      final userData = SharedPrefsHelper.getUserData();
      final allProdWorkOrders = await _odooService.fetchWorkOrdersByProductionId(
        database: userData!['database'],
        userId: userData['userId'],
        password: userData['password'],
        productionId: _currentWorkOrder.productionId!,
      );

      priorOps = allProdWorkOrders.where((wo) {
        final id = wo['id'];
        final rawSeq = wo['sequence'];
        final seq = (rawSeq is num) ? rawSeq.toInt() : null;
        if (seq == null || id == _currentWorkOrder.id) return false;
        return seq < _currentWorkOrder.sequence!;
      }).toList();
    } catch (e) {
      print('⚠️ خطأ في جلب العمليات السابقة: $e');
    } finally {
      setState(() => _isLoading = false);
    }

    if (priorOps.isEmpty) return true;

    final confirmed = await _showPriorOperationsWizard(priorOps);
    return confirmed == true;
  }

  Map<String, dynamic> _translateRawWorkOrderState(String? rawState, AppLocalizations localizations) {
    switch (rawState) {
      case 'waiting':
        return {'label': localizations.translate('waiting'), 'color': Colors.grey};
      case 'ready':
        return {'label': localizations.translate('ready'), 'color': Colors.blue};
      case 'progress':
        return {'label': localizations.translate('in_progress'), 'color': Colors.orange};
      case 'pending':
        return {'label': localizations.translate('pending'), 'color': Colors.amber};
      case 'done':
        return {'label': localizations.translate('done_status'), 'color': Colors.green};
      case 'cancel':
        return {'label': localizations.translate('cancelled'), 'color': Colors.red};
      default:
        return {'label': rawState ?? '--', 'color': Colors.grey};
    }
  }

  // ⭐ Wizard على شكل جدول: يعرض اسم العملية وحالتها لكل عملية سابقة في التسلسل
  Future<bool?> _showPriorOperationsWizard(List<Map<String, dynamic>> priorOps) {
    final localizations = AppLocalizations.of(context);

    priorOps.sort((a, b) {
      final seqA = (a['sequence'] is num) ? (a['sequence'] as num).toInt() : 0;
      final seqB = (b['sequence'] is num) ? (b['sequence'] as num).toInt() : 0;
      return seqA.compareTo(seqB);
    });

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.list_alt_rounded, color: Colors.blue, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        localizations.translate('prior_operations_title'),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      icon: const Icon(Icons.close, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  localizations.translate('prior_operations_message'),
                  style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          localizations.translate('operation_column'),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          localizations.translate('status_column'),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: priorOps.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
                    itemBuilder: (context, index) {
                      final wo = priorOps[index];
                      final name = wo['name']?.toString() ?? '--';
                      final rawState = wo['state']?.toString();
                      final statusInfo = _translateRawWorkOrderState(rawState, localizations);
                      final statusColor = statusInfo['color'] as Color;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                name,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: statusColor.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    statusInfo['label'],
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          localizations.translate('cancel'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF455A64),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: Text(
                          localizations.translate('continue'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ⭐ الجسم الفعلي لبدء/استئناف العمل (بعد اجتياز فحص التسلسل إن وُجد)
  Future<void> _performStart() async {
    setState(() => _isLoading = true);
    try {
      final userData = SharedPrefsHelper.getUserData();
      final employeeId = userData!['employeeId'] as int;

      final allOrders = await _odooService.fetchWorkOrders(
        database: userData['database'],
        userId: userData['userId'],
        password: userData['password'],
        employeeId: employeeId,
      );

      Map<String, dynamic>? busyWorkOrderJson;
      for (final wo in allOrders) {
        final isWorking = wo['is_user_working'] == true;
        final isDifferentWorkOrder = wo['id'] != _currentWorkOrder.id;
        if (isWorking && isDifferentWorkOrder) {
          busyWorkOrderJson = wo;
          break;
        }
      }

      if (busyWorkOrderJson != null) {
        setState(() => _isLoading = false);
        final busyWorkOrder = WorkOrderModel.fromJson(busyWorkOrderJson);
        _showAlreadyWorkingDialog(busyWorkOrder);
        return;
      }

      await _odooService.startWorkOrder(
        database: userData['database'],
        userId: userData['userId'],
        password: userData['password'],
        workOrderId: _currentWorkOrder.id,
      );
      _showSuccess(AppLocalizations.of(context).translate('operation_started'));
      await _refreshWorkOrder();
    } catch (e) {
      _showError(e.toString());
      setState(() => _isLoading = false);
    }
  }

  // ⭐ Dialog حديث: يعرض معلومات أمر العمل المشغول به الموظف حالياً + زر إغلاق + زر فتح تفاصيله
  void _showAlreadyWorkingDialog(WorkOrderModel busyWorkOrder) {
    final localizations = AppLocalizations.of(context);
    final cleanProduct = _cleanProductName(busyWorkOrder.productName);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 8,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.pending_actions_rounded, color: Colors.orange[700], size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                localizations.translate('already_working_title'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                localizations.translate('already_working_subtitle'),
                style: TextStyle(fontSize: 13.5, color: Colors.grey[600], height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.assignment_rounded, size: 16, color: Colors.orange[800]),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            busyWorkOrder.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (cleanProduct != null && cleanProduct.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.inventory_2_outlined, size: 16, color: Colors.orange[800]),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cleanProduct,
                              style: TextStyle(fontSize: 13, color: Colors.grey[800], fontWeight: FontWeight.w500),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (busyWorkOrder.workcenterName != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.factory_outlined, size: 16, color: Colors.orange[800]),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              busyWorkOrder.workcenterName!,
                              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        localizations.translate('close'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WorkOrderDetailsView(workOrder: busyWorkOrder),
                          ),
                        );
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(
                        localizations.translate('open'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF455A64),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ⭐ Wizard اختيار سبب التوقف المؤقت قبل تنفيذ Pause
  void _showPauseReasonDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => _PauseReasonDialog(
        onConfirm: (reason) {
          Navigator.pop(dialogContext);
          _handlePause(reason: reason);
        },
      ),
    );
  }

  Future<void> _handlePause({String? reason}) async {
    setState(() => _isLoading = true);
    try {
      final userData = SharedPrefsHelper.getUserData();
      await _odooService.pauseWorkOrder(
        database: userData!['database'],
        userId: userData['userId'],
        password: userData['password'],
        workOrderId: _currentWorkOrder.id,
      );
      final baseMessage = AppLocalizations.of(context).translate('operation_paused');
      _showSuccess(reason != null && reason.isNotEmpty ? '$baseMessage - $reason' : baseMessage);
      await _refreshWorkOrder();
      await _checkAndNotifyDurationExceeded();
    } catch (e) {
      _showError(e.toString());
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleBlock() async {
    _showBlockDialog();
  }

  Future<void> _showBlockDialog() async {
    final userData = SharedPrefsHelper.getUserData();
    final localizations = AppLocalizations.of(context);

    setState(() => _isLoading = true);

    try {
      final lossReasons = await _odooService.getLossReasons(
        database: userData!['database'],
        userId: userData['userId'],
        password: userData['password'],
      );

      setState(() => _isLoading = false);

      if (lossReasons.isEmpty) {
        _showError(localizations.translate('no_loss_reasons'));
        return;
      }

      final translatedReasons = lossReasons.map((reason) {
        final id = reason['id'];
        final translationKey = 'loss_$id';
        final translated = localizations.translate(translationKey);

        return {
          'id': id,
          'name': translated != translationKey ? translated : reason['name'],
        };
      }).toList();

      showDialog(
        context: context,
        builder: (context) => _BlockDialog(
          lossReasons: translatedReasons,
          onBlock: (lossId, description) async {
            Navigator.pop(context);
            await _performBlock(lossId, description);
          },
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(e.toString());
    }
  }

  Future<void> _performBlock(int lossId, String description) async {
    setState(() => _isLoading = true);
    try {
      final userData = SharedPrefsHelper.getUserData();
      await _odooService.blockWorkOrder(
        database: userData!['database'],
        userId: userData['userId'],
        password: userData['password'],
        workOrderId: _currentWorkOrder.id,
        companyId: _currentWorkOrder.companyId!,
        workcenterId: _currentWorkOrder.workcenterId!,
        lossId: lossId,
        description: description,
      );
      _showSuccess(AppLocalizations.of(context).translate('operation_blocked'));
      await _refreshWorkOrder();
    } catch (e) {
      _showError(e.toString());
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUnblock() async {
    setState(() => _isLoading = true);
    try {
      final userData = SharedPrefsHelper.getUserData();
      await _odooService.unblockWorkOrder(
        database: userData!['database'],
        userId: userData['userId'],
        password: userData['password'],
        workOrderId: _currentWorkOrder.id,
      );
      _showSuccess(AppLocalizations.of(context).translate('operation_unblocked'));
      await _refreshWorkOrder();
    } catch (e) {
      _showError(e.toString());
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleTerminate() async {
    await _showTerminateConfirmation();
  }

  Future<void> _showTerminateConfirmation() async {
    final localizations = AppLocalizations.of(context);
    final TextEditingController confirmController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (statefulContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              contentPadding: const EdgeInsets.all(24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_rounded,
                      size: 40,
                      color: Colors.orange[700],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    localizations.translate('confirm_termination'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    localizations.translate('confirm_termination_message'),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: confirmController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: localizations.translate('type_ok_to_confirm'),
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontWeight: FontWeight.normal,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.orange[700]!, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (value) {
                      setDialogState(() {});
                    },
                  ),
                ],
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop(false);
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey[400]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          localizations.translate('cancel'),
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: confirmController.text.toLowerCase() == 'ok'
                            ? () {
                          Navigator.of(dialogContext).pop(true);
                        }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[700],
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: Text(
                          localizations.translate('confirm'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      await _performTerminate();
    }
  }

  Future<void> _performTerminate() async {
    setState(() => _isLoading = true);

    try {
      final userData = SharedPrefsHelper.getUserData();

      final success = await _odooService.finishWorkOrder(
        database: userData!['database'],
        userId: userData['userId'],
        password: userData['password'],
        workOrderId: _currentWorkOrder.id,
      );

      if (success) {
        _showSuccess(AppLocalizations.of(context).translate('operation_terminated'));

        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('Failed to terminate work order');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, LanguageController controller, AppLocalizations localizations) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 5,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF3F51B5).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.language,
                  color: Color(0xFF3F51B5),
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                localizations.translate('change_language'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF9900),
                ),
              ),
              const SizedBox(height: 24),
              _buildLanguageOption(
                context: dialogContext,
                controller: controller,
                languageCode: 'fr',
                languageName: 'Français',
                flag: '🇫🇷',
                color: const Color(0xFF3F51B5),
              ),
              const SizedBox(height: 12),
              _buildLanguageOption(
                context: dialogContext,
                controller: controller,
                languageCode: 'ar',
                languageName: 'العربية',
                flag: '🇹🇳',
                color: const Color(0xFF5C6BC0),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  localizations.translate('cancel'),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required LanguageController controller,
    required String languageCode,
    required String languageName,
    required String flag,
    required Color color,
  }) {
    final isSelected = controller.locale.languageCode == languageCode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await controller.changeLanguage(languageCode);
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  flag,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  languageName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? color : Colors.grey[800],
                  ),
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 20,
                  ),
                )
              else
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthController authController, AppLocalizations localizations) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                localizations.translate('logout'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            localizations.translate('confirm_logout'),
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              localizations.translate('no'),
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await authController.logout();
              Navigator.pop(dialogContext);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginView()),
                    (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              localizations.translate('yes'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String? _cleanProductName(String? productName) {
    if (productName == null || productName.isEmpty) return null;
    final cleanName = productName.replaceAll(RegExp(r'^\[.*?\]\s*'), '');
    return cleanName.trim();
  }

  bool _isDateScheduled(String? date) {
    if (date == null || date.isEmpty) return false;
    if (date.toLowerCase() == 'false' || date.toLowerCase() == 'null') return false;
    try {
      DateTime.parse(date);
      return true;
    } catch (e) {
      return false;
    }
  }

  String _formatDate(String? date) {
    if (!_isDateScheduled(date)) return '--';
    try {
      final parsedDate = DateTime.parse(date!);
      return DateFormat('dd/MM/yyyy HH:mm').format(parsedDate);
    } catch (e) {
      return '--';
    }
  }

  String _formatDuration(double minutes) {
    if (minutes == 0) return '--';
    final hours = minutes ~/ 60;
    final mins = (minutes % 60).toInt();
    if (hours > 0) {
      return '${hours}h ${mins}m';
    } else {
      return '${mins}m';
    }
  }

  IconData _getStatusIcon(WorkOrderStatus status) {
    switch (status) {
      case WorkOrderStatus.waiting:
        return Icons.schedule;
      case WorkOrderStatus.blocked:
        return Icons.block;
      case WorkOrderStatus.pending:
        return Icons.pending;
      case WorkOrderStatus.inProgress:
        return Icons.play_circle;
      case WorkOrderStatus.paused:
        return Icons.pause_circle;
    }
  }

  Map<String, dynamic> _getStatusInfo(WorkOrderStatus status, AppLocalizations localizations) {
    switch (status) {
      case WorkOrderStatus.waiting:
        return {'label': localizations.translate('waiting'), 'color': Colors.grey[700]};
      case WorkOrderStatus.blocked:
        return {'label': localizations.translate('blocked'), 'color': Colors.red};
      case WorkOrderStatus.pending:
        return {'label': localizations.translate('pending'), 'color': Colors.green};
      case WorkOrderStatus.inProgress:
        return {'label': localizations.translate('in_progress'), 'color': Colors.blue};
      case WorkOrderStatus.paused:
        return {'label': localizations.translate('paused'), 'color': Colors.orange};
    }
  }
}

// ⭐ Wizard اختيار سبب التوقف المؤقت
class _PauseReasonDialog extends StatefulWidget {
  final void Function(String reason) onConfirm;

  const _PauseReasonDialog({required this.onConfirm});

  @override
  State<_PauseReasonDialog> createState() => _PauseReasonDialogState();
}

class _PauseReasonDialogState extends State<_PauseReasonDialog> {
  String? _selectedKey;
  final _otherController = TextEditingController();

  static const List<String> _reasonKeys = [
    'pause_reason_breakfast',
    'pause_reason_dhuhr',
    'pause_reason_asr',
    'pause_reason_smoke',
    'pause_reason_other',
  ];

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  bool get _isOtherSelected => _selectedKey == 'pause_reason_other';

  bool get _isValid {
    if (_selectedKey == null) return false;
    if (_isOtherSelected) return _otherController.text.trim().isNotEmpty;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return StatefulBuilder(
      builder: (context, setDialogState) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.pause_circle_outline, color: Colors.orange, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        localizations.translate('pause_reason_title'),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  localizations.translate('pause_reason_select'),
                  style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedKey,
                      hint: Row(
                        children: [
                          Icon(Icons.list, size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            localizations.translate('pause_reason_select'),
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      items: _reasonKeys
                          .map((key) => DropdownMenuItem<String>(
                        value: key,
                        child: Text(
                          localizations.translate(key),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ))
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          _selectedKey = value;
                        });
                      },
                    ),
                  ),
                ),
                if (_isOtherSelected) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _otherController,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      hintText: localizations.translate('pause_reason_other_hint'),
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.orange, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      prefixIcon: const Icon(Icons.edit_outlined, size: 20),
                    ),
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          localizations.translate('cancel'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isValid
                            ? () {
                          final reason = _isOtherSelected
                              ? _otherController.text.trim()
                              : localizations.translate(_selectedKey!);
                          widget.onConfirm(reason);
                        }
                            : null,
                        icon: const Icon(Icons.pause_rounded, size: 18),
                        label: Text(
                          localizations.translate('pause'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ⭐ Block Dialog Widget
class _BlockDialog extends StatefulWidget {
  final List<Map<String, dynamic>> lossReasons;
  final Function(int lossId, String description) onBlock;

  const _BlockDialog({required this.lossReasons, required this.onBlock});

  @override
  State<_BlockDialog> createState() => _BlockDialogState();
}

class _BlockDialogState extends State<_BlockDialog> {
  int? _selectedLossId;
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block, color: Colors.red, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    localizations.translate('block_reason'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              localizations.translate('select_reason'),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _selectedLossId,
                  hint: Row(
                    children: [
                      Icon(Icons.list, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        localizations.translate('select_reason'),
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  items: widget.lossReasons
                      .map((reason) => DropdownMenuItem<int>(
                    value: reason['id'],
                    child: Text(
                      reason['name'],
                      style: const TextStyle(fontSize: 13),
                    ),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedLossId = value;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              localizations.translate('description'),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                hintText: localizations.translate('description') + '...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                prefixIcon: Icon(Icons.description, color: Colors.grey[600], size: 20),
              ),
              style: const TextStyle(fontSize: 13),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      localizations.translate('cancel'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedLossId == null
                        ? null
                        : () => widget.onBlock(_selectedLossId!, _descriptionController.text),
                    icon: const Icon(Icons.block, size: 18),
                    label: Text(
                      localizations.translate('block'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
