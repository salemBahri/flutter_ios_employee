import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:convert';
import '../models/component_model.dart';
import '../models/special_component_config.dart';
import '../services/odoo_service.dart';
import '../utils/app_localizations.dart';
import '../utils/shared_prefs_helper.dart';

class ComponentsView extends StatefulWidget {
  final int productionId;
  final int workcenterId;
  final String productionName;
  final String workorderName;

  const ComponentsView({
    Key? key,
    required this.productionId,
    required this.workcenterId,
    required this.productionName,
    required this.workorderName,
  }) : super(key: key);

  @override
  State<ComponentsView> createState() => _ComponentsViewState();
}

class _ComponentsViewState extends State<ComponentsView> {
  final OdooService _odooService = OdooService();
  bool _isLoading = false;
  List<ComponentModel> _components = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadComponents();
  }

  Future<void> _loadComponents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userData = SharedPrefsHelper.getUserData();
      if (userData == null) {
        if (!mounted) return;
        setState(() {
          _error = 'User session expired. Please login again.';
          _isLoading = false;
        });
        return;
      }

      final componentsData = await _odooService.getWorkCenterComponents(
        database: userData['database'],
        userId: userData['userId'],
        password: userData['password'],
        productionId: widget.productionId,
        workcenterId: widget.workcenterId,
        workorderName: widget.workorderName,
      );

      if (!mounted) return;
      setState(() {
        _components = componentsData
            .map((json) => ComponentModel.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateQuantity(
      ComponentModel component, double newQuantity) async {
    setState(() => _isLoading = true);

    try {
      final userData = SharedPrefsHelper.getUserData();
      if (userData == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showError('User session expired. Please login again.');
        return;
      }

      await _odooService.updateComponentQuantityDone(
        database: userData['database'],
        userId: userData['userId'],
        password: userData['password'],
        moveId: component.id,
        newQuantityDone: newQuantity,
      );

      if (!mounted) return;
      _showSuccess(AppLocalizations.of(context).translate('quantity_updated'));
      await _loadComponents();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF455A64),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.translate('components'),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            Text(
              widget.productionName,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8), fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadComponents,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading && _components.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            _buildErrorView(localizations)
          else if (_components.isEmpty)
              _buildEmptyView(localizations)
            else
              RefreshIndicator(
                onRefresh: _loadComponents,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _components.length,
                  itemBuilder: (context, index) {
                    final component = _components[index];
                    return _buildComponentCard(component, localizations, index);
                  },
                ),
              ),
          if (_isLoading && _components.isNotEmpty)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _buildComponentCard(
      ComponentModel component, AppLocalizations localizations, int index) {
    final progress = component.progressPercentage;
    final stateColor = component.getStateColor();
    final specialCfg = SpecialComponentsRegistry.find(component.productId);
    final isSimpleM2 = SimpleM2ComponentMatcher.matches(component.productName);
    final effectiveSpecialCfg = isSimpleM2 ? null : specialCfg;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => effectiveSpecialCfg != null
            ? _showSpecialQuantityDialog(component, effectiveSpecialCfg, localizations)
            : _showQuantityDialog(component, localizations, isM2: isSimpleM2),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildProductImage(component),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          component.productName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                component.getStateLabel(localizations),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: stateColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (effectiveSpecialCfg != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  localizations.translate('formulaire'),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.blue),
                                ),
                              ),
                            if (isSimpleM2)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  "m²",
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.teal),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    component.isComplete ? Icons.check_circle : Icons.edit,
                    color: component.isComplete ? Colors.green : Colors.orange,
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${component.quantityDone.toStringAsFixed(2)} / ${component.productUomQty.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getProgressColor(progress).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: _getProgressColor(progress)
                                  .withOpacity(0.3)),
                        ),
                        child: Text(
                          '${progress.toInt()}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getProgressColor(progress),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress / 100,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(
                          _getProgressColor(progress)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (component.reservedAvailability >=
                      component.productUomQty
                      ? Colors.green
                      : component.reservedAvailability > 0
                      ? Colors.orange
                      : Colors.red)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      component.reservedAvailability >= component.productUomQty
                          ? Icons.check_circle_outline
                          : component.reservedAvailability > 0
                          ? Icons.warning_amber_outlined
                          : Icons.cancel_outlined,
                      size: 14,
                      color: component.reservedAvailability >=
                          component.productUomQty
                          ? Colors.green[700]
                          : component.reservedAvailability > 0
                          ? Colors.orange[700]
                          : Colors.red[700],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${localizations.translate('reserved')}: ${component.reservedAvailability.toStringAsFixed(2)} / ${component.productUomQty.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: component.reservedAvailability >=
                            component.productUomQty
                            ? Colors.green[700]
                            : component.reservedAvailability > 0
                            ? Colors.orange[700]
                            : Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms);
  }

  Widget _buildProductImage(ComponentModel component) {
    return GestureDetector(
      onTap: () => _showFullImage(component),
      child: Hero(
        tag: 'component_${component.id}',
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!, width: 1),
            color: Colors.white,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: _buildImageWidget(
              component.productImageBase64?['thumbnail'],
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageWidget(String? base64Image, {double size = 24}) {
    if (base64Image != null && base64Image.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(base64Image),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _defaultIcon(size),
        );
      } catch (e) {
        debugPrint('❌ Error decoding image: $e');
        return _defaultIcon(size);
      }
    }
    return _defaultIcon(size);
  }

  Widget _defaultIcon(double size) {
    return Container(
      color: Colors.grey[100],
      child: Icon(Icons.inventory_2, color: Colors.grey[400], size: size),
    );
  }

  void _showFullImage(ComponentModel component) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Center(
              child: Hero(
                tag: 'component_${component.id}',
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.7,
                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFF455A64),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                component.productName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          child: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: _buildImageWidget(
                              component.productImageBase64?['full'],
                              size: 64,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child:
                  const Icon(Icons.close, color: Colors.white, size: 24),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuantityDialog(
      ComponentModel component, AppLocalizations localizations,
      {bool isM2 = false}) {
    final controller = TextEditingController(
      text: component.quantityDone.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isM2 ? Colors.teal : Colors.blue).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isM2 ? Icons.square_foot : Icons.edit,
                color: isM2 ? Colors.teal : Colors.blue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isM2
                    ? localizations.translate('update_surface')
                    : localizations.translate('update_quantity'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                component.productName,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isM2
                      ? "${localizations.translate('quantity_done')} (m²)"
                      : localizations.translate('quantity_done'),
                  hintText: '0.00',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  prefixIcon: Icon(
                    isM2 ? Icons.square_foot : Icons.format_list_numbered,
                    color: isM2 ? Colors.teal : Colors.blue,
                  ),
                  suffixText: isM2
                      ? "m²"
                      : '/ ${component.productUomQty.toStringAsFixed(2)}',
                ),
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final newQty = double.tryParse(controller.text);
              if (newQty != null) {
                Navigator.pop(context);
                _updateQuantity(component, newQty);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isM2 ? Colors.teal : Colors.blue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(localizations.translate('update')),
          ),
        ],
      ),
    );
  }

  void _showSpecialQuantityDialog(
      ComponentModel component,
      SpecialComponentConfig cfg,
      AppLocalizations localizations) {
    final controllers = List.generate(cfg.factors.length, (_) => TextEditingController());
    bool isCalculated = false;
    double? totalResult;
    List<double> breakdown = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final allFilled = controllers.every(
                  (c) => double.tryParse(c.text.replaceAll(',', '.')) != null);

          void recalc() {
            breakdown = [];
            double total = 0;
            for (int i = 0; i < cfg.factors.length; i++) {
              final typed = double.parse(controllers[i].text.replaceAll(',', '.'));
              final tI = (cfg.factors[i] * cfg.secondFactor * typed) / cfg.divisor;
              breakdown.add(tI);
              total += tI;
            }
            totalResult = total;
            isCalculated = true;
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF455A64), Color(0xFF37474F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.calculate_rounded, color: Colors.white, size: 30),
                          const SizedBox(height: 8),
                          Text(
                            cfg.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            component.productName,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        children: List.generate(cfg.factors.length, (i) {
                          final f = cfg.factors[i];
                          final label = "${f % 1 == 0 ? f.toInt() : f} x ${cfg.secondFactor}";
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 70,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: controllers[i],
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      border: InputBorder.none,
                                      suffixText: cfg.unitSuffix,
                                      hintText: "0.00",
                                      hintStyle: TextStyle(color: Colors.grey.shade400),
                                    ),
                                    onChanged: (_) => setState(() => isCalculated = false),
                                  ),
                                ),
                                if (isCalculated && i < breakdown.length)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.green),
                                        const SizedBox(width: 4),
                                        Text(
                                          breakdown[i].toStringAsFixed(4),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                    if (isCalculated && totalResult != null)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                                SizedBox(width: 8),
                                Text("Total", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                              ],
                            ),
                            Text(
                              totalResult!.toStringAsFixed(4),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(localizations.translate('cancel')),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: !allFilled
                                    ? Colors.grey
                                    : (isCalculated ? Colors.green : Colors.blue),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              icon: Icon(
                                isCalculated ? Icons.save_rounded : Icons.calculate_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: !allFilled
                                  ? null
                                  : () {
                                if (!isCalculated) {
                                  setState(() => recalc());
                                } else {
                                  Navigator.pop(context);
                                  _updateQuantity(component, totalResult!);
                                }
                              },
                              label: Text(
                                isCalculated ? localizations.translate('save') : localizations.translate('calculate'),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyView(AppLocalizations localizations) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            localizations.translate('no_components'),
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(AppLocalizations localizations) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadComponents,
              icon: const Icon(Icons.refresh),
              label: Text(localizations.translate('retry')),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress >= 100) return Colors.green;
    if (progress >= 50) return Colors.orange;
    return Colors.red;
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
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}