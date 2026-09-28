import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../controllers/auth_controller.dart';
import '../controllers/language_controller.dart';
import '../controllers/workorders_controller.dart';
import '../models/workorder_model.dart';
import '../utils/app_localizations.dart';
import '../services/notification_service.dart';
import 'login_view.dart';
import 'workorder_details_view.dart';
import 'notifications_history_view.dart';

class MyWorkorderView extends StatefulWidget {
  const MyWorkorderView({Key? key}) : super(key: key);

  @override
  State<MyWorkorderView> createState() => _MyWorkorderViewState();
}

class _MyWorkorderViewState extends State<MyWorkorderView> {
  WorkOrderStatus? _selectedStatusFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authController = Provider.of<AuthController>(context, listen: false);
      final languageController = Provider.of<LanguageController>(context, listen: false);
      final workordersController = Provider.of<WorkOrdersController>(context, listen: false);

      authController.loadUserFromPrefs();
      workordersController.loadWorkOrders();
      workordersController.startPolling(langCode: languageController.locale.languageCode);
    });
  }

  @override
  void dispose() {
    Provider.of<WorkOrdersController>(context, listen: false).stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final languageController = Provider.of<LanguageController>(context);
    final workordersController = Provider.of<WorkOrdersController>(context);
    final localizations = AppLocalizations.of(context);

    final employeeName = authController.currentEmployee?.name ??
        authController.currentUser?.username ??
        'User';
    final departmentName = authController.currentEmployee?.departmentName ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _buildAppBar(employeeName, departmentName, languageController, authController, localizations),
      body: Column(
        children: [
          _buildImprovedFilterBar(workordersController, localizations),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => workordersController.loadWorkOrders(),
              child: _buildWorkOrdersList(workordersController, localizations),
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
        // ⭐⭐ زر اختبار مباشر للإشعارات (مؤقت للتشخيص - يمكن حذفه بعد التأكد إن كل شيء يعمل)
        /*IconButton(
          icon: const Icon(Icons.bug_report_outlined, color: Colors.white, size: 24),
          tooltip: 'اختبار الإشعار',
          onPressed: () async {
            await NotificationService().showTestNotification();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم استدعاء الإشعار التجريبي - راجع شريط الإشعارات والـ console')),
              );
            }
          },
        ),*/
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
          tooltip: localizations.translate('notifications'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NotificationsHistoryView()),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.language, color: Colors.white, size: 24),
          tooltip: localizations.translate('change_language'),
          onPressed: () => _showLanguageDialog(context, languageController),
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

  Widget _buildImprovedFilterBar(WorkOrdersController controller, AppLocalizations localizations) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => controller.toggleUrgentFilter(),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: controller.urgentFilterActive
                      ? Colors.red
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.red.withOpacity(controller.urgentFilterActive ? 1 : 0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.priority_high_rounded,
                      size: 20,
                      color: controller.urgentFilterActive ? Colors.white : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      localizations.translate('urgent'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: controller.urgentFilterActive ? Colors.white : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<WorkOrderStatus?>(
                  isExpanded: true,
                  value: _selectedStatusFilter,
                  icon: Icon(Icons.expand_more, color: Colors.grey[700]),
                  style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                  hint: Row(
                    children: [
                      Icon(Icons.filter_list_rounded, size: 18, color: Colors.grey[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          localizations.translate('all_states'),
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  items: [
                    DropdownMenuItem<WorkOrderStatus?>(
                      value: null,
                      child: _buildDropdownItem(
                        Icons.all_inclusive_rounded,
                        localizations.translate('all_states'),
                        Colors.grey[700]!,
                      ),
                    ),
                    ...WorkOrderStatus.values.map((status) {
                      final info = _getStatusInfo(status, localizations);
                      return DropdownMenuItem<WorkOrderStatus?>(
                        value: status,
                        child: _buildDropdownItem(
                          _getStatusIcon(status),
                          info['label'],
                          info['color'],
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatusFilter = value;
                    });
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownItem(IconData icon, String label, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkOrdersList(WorkOrdersController controller, AppLocalizations localizations) {
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.error != null) {
      return _buildErrorView(controller, localizations);
    }

    final filteredOrders = _selectedStatusFilter == null
        ? controller.workOrders
        : controller.workOrders.where((wo) => wo.customStatus == _selectedStatusFilter).toList();

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_outline, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              localizations.translate('no_workorders'),
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filteredOrders.length,
      itemBuilder: (context, index) {
        final workorder = filteredOrders[index];
        return _buildCompactCard(workorder, localizations, index);
      },
    );
  }

  Widget _buildCompactCard(WorkOrderModel workorder, AppLocalizations localizations, int index) {
    final statusInfo = _getStatusInfo(workorder.customStatus, localizations);
    final statusColor = statusInfo['color'] as Color;
    final cleanProductName = _cleanProductName(workorder.productName);

    final isDatesScheduled = _isDateScheduled(workorder.datePlannedStart);

    final hasResponsible = workorder.hasProductionUser;

    final card = Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: hasResponsible ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hasResponsible
            ? const BorderSide(color: Colors.blue, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WorkOrderDetailsView(workOrder: workorder),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: hasResponsible ? Colors.blue.withOpacity(0.04) : null,
            border: Border(
              left: BorderSide(color: statusColor, width: 5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getStatusIcon(workorder.customStatus),
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    if (workorder.isUrgent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.priority_high,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                    if (hasResponsible) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 16,
                        ),
                      ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                          .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.15, 1.15),
                        duration: 700.ms,
                        curve: Curves.easeInOut,
                      ),
                    ],
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            workorder.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                          if (workorder.productionName != null)
                            Text(
                              workorder.productionName!,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        statusInfo['label'],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (hasResponsible && workorder.productionUserName != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.badge_outlined, size: 12, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          workorder.productionUserName!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (cleanProductName != null && cleanProductName.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            cleanProductName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[800],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (workorder.workcenterName != null)
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.factory_outlined, size: 14, color: Colors.blue[700]),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  workorder.workcenterName!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue[900],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: isDatesScheduled
                          ? Row(
                        children: [
                          Expanded(
                            child: _buildDateBadge(
                              Icons.play_circle_outline,
                              workorder.datePlannedStart,
                              Colors.green,
                              localizations,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildDateBadge(
                              Icons.flag_outlined,
                              workorder.datePlannedFinished,
                              Colors.orange,
                              localizations,
                            ),
                          ),
                        ],
                      )
                          : _buildNotScheduledBadge(localizations),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms, delay: (index * 30).ms);

    if (!hasResponsible) {
      return card;
    }

    return card
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .boxShadow(
      begin: BoxShadow(
        color: Colors.blue.withOpacity(0.15),
        blurRadius: 4,
        spreadRadius: 0,
      ),
      end: BoxShadow(
        color: Colors.blue.withOpacity(0.55),
        blurRadius: 14,
        spreadRadius: 2,
      ),
      duration: 900.ms,
      curve: Curves.easeInOut,
    );
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

  Widget _buildNotScheduledBadge(AppLocalizations localizations) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule_outlined, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              localizations.translate('not_scheduled'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateBadge(IconData icon, String? date, Color color, AppLocalizations localizations) {
    String displayText;
    bool isScheduled = _isDateScheduled(date);

    if (!isScheduled) {
      displayText = localizations.translate('not_scheduled');
    } else {
      try {
        final parsedDate = DateTime.parse(date!);
        displayText = DateFormat('dd/MM').format(parsedDate);
      } catch (e) {
        displayText = localizations.translate('not_scheduled');
        isScheduled = false;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(height: 2),
          Text(
            displayText,
            style: TextStyle(
              fontSize: isScheduled ? 11 : 8,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

  Widget _buildErrorView(WorkOrdersController controller, AppLocalizations localizations) {
    final isAccessDenied = controller.error!.contains('Access Denied') ||
        controller.error!.contains('كلمة المرور');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isAccessDenied ? Icons.lock_outline : Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              controller.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: isAccessDenied
                  ? () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginView()),
                      (route) => false,
                );
              }
                  : () => controller.loadWorkOrders(),
              icon: Icon(isAccessDenied ? Icons.login : Icons.refresh),
              label: Text(localizations.translate(isAccessDenied ? 'login' : 'retry')),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
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
        return {'label': localizations.translate('waiting'), 'color': Colors.grey};
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

  void _showLanguageDialog(BuildContext context, LanguageController controller) {
    final localizations = AppLocalizations.of(context);

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
          if (mounted) {
            Provider.of<WorkOrdersController>(context, listen: false)
                .updateLanguage(languageCode);
          }
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
}
