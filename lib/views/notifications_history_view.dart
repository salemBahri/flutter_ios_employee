import 'package:flutter/material.dart';
import '../services/notification_db_helper.dart';
import '../utils/app_localizations.dart';
import '../utils/shared_prefs_helper.dart';

class NotificationsHistoryView extends StatefulWidget {
  const NotificationsHistoryView({Key? key}) : super(key: key);

  @override
  State<NotificationsHistoryView> createState() => _NotificationsHistoryViewState();
}

class _NotificationsHistoryViewState extends State<NotificationsHistoryView> {
  final NotificationDbHelper _notificationDb = NotificationDbHelper();

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userData = SharedPrefsHelper.getUserData();
    final userId = userData?['userId'];

    if (userId == null) {
      if (mounted) {
        setState(() {
          _items = [];
          _loading = false;
        });
      }
      return;
    }

    final list = await _notificationDb.getNotificationsForUser(userId);

    if (mounted) {
      setState(() {
        _items = list;
        _loading = false;
        _selectionMode = false;
        _selectedIds.clear();
      });
    }
  }

  String _dayLabel(DateTime d, AppLocalizations loc) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return loc.translate('today');
    if (diff == 1) return loc.translate('yesterday');
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _formatTime(DateTime d) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Map<String, List<Map<String, dynamic>>> _groupByDay(AppLocalizations loc) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final n in _items) {
      final d = DateTime.tryParse(n['created_at'] as String? ?? '') ?? DateTime.now();
      final key = _dayLabel(d, loc);
      grouped.putIfAbsent(key, () => []).add(n);
    }
    return grouped;
  }

  Future<bool> _confirmDelete(String title, String message, AppLocalizations loc) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.translate('no')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.translate('delete')),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _deleteSingle(int id, AppLocalizations loc) async {
    final confirmed = await _confirmDelete(
      loc.translate('delete_notification_title'),
      loc.translate('delete_notification_message'),
      loc,
    );
    if (confirmed) {
      await _notificationDb.deleteById(id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.translate('notification_deleted'))),
        );
      }
    }
  }

  Future<void> _deleteSelected(AppLocalizations loc) async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await _confirmDelete(
      loc.translate('delete_selected_title'),
      loc.translate('delete_selected_message'),
      loc,
    );
    if (confirmed) {
      await _notificationDb.deleteByIds(_selectedIds.toList());
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.translate('notifications_deleted'))),
        );
      }
    }
  }

  Future<void> _deleteAll(AppLocalizations loc) async {
    final userData = SharedPrefsHelper.getUserData();
    final userId = userData?['userId'];
    if (userId == null) return;

    final confirmed = await _confirmDelete(
      loc.translate('delete_all_title'),
      loc.translate('delete_all_message'),
      loc,
    );
    if (confirmed) {
      await _notificationDb.deleteAllForUser(userId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.translate('notifications_deleted'))),
        );
      }
    }
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  void _enterSelectionMode(int id) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  /// ⭐ يبني قائمة TextSpan تلوّن highlight1/highlight2 (اسم الموظف والمنتج) بالأحمر Bold
  /// داخل نص الإشعار - هذا يشتغل 100% لأنه Text عادي داخل التطبيق (مو إشعار نظام)
  List<TextSpan> _buildHighlightedSpans(String text, List<String?> highlights) {
    final validHighlights = highlights
        .whereType<String>()
        .where((h) => h.isNotEmpty && text.contains(h))
        .toSet()
        .toList();

    if (validHighlights.isEmpty) {
      return [TextSpan(text: text)];
    }

    final pattern = validHighlights.map((h) => RegExp.escape(h)).join('|');
    final regex = RegExp(pattern);

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return spans;
  }

  Widget _highlightedBody(Map<String, dynamic> n) {
    final body = n['body'] as String? ?? '';
    final highlight1 = n['highlight1'] as String?;
    final highlight2 = n['highlight2'] as String?;

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, color: Colors.black87),
        children: _buildHighlightedSpans(body, [highlight1, highlight2]),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'new_workorder':
        return Icons.assignment_add;
      case 'duration_exceeded':
        return Icons.timer_off;
      default:
        return Icons.notifications;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'new_workorder':
        return Colors.blue;
      case 'duration_exceeded':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final grouped = _groupByDay(loc);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF455A64),
        elevation: 0,
        leading: _selectionMode
            ? IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _cancelSelection,
        )
            : null,
        title: Text(
          _selectionMode
              ? '${_selectedIds.length} ${loc.translate('selected')}'
              : loc.translate('notifications'),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (_selectionMode && _selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              tooltip: loc.translate('delete'),
              onPressed: () => _deleteSelected(loc),
            )
          else if (!_selectionMode && _items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              tooltip: loc.translate('delete_all_title'),
              onPressed: () => _deleteAll(loc),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              loc.translate('no_notifications'),
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: grouped.entries.expand((entry) {
            return [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  entry.key,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              ...entry.value.map((n) {
                final id = n['id'] as int;
                final type = n['type'] as String;
                final d = DateTime.tryParse(n['created_at'] as String? ?? '') ?? DateTime.now();
                final selected = _selectedIds.contains(id);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Dismissible(
                    key: ValueKey(id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) => _confirmDelete(
                      loc.translate('delete_notification_title'),
                      loc.translate('delete_notification_message'),
                      loc,
                    ),
                    onDismissed: (_) async {
                      await _notificationDb.deleteById(id);
                      setState(() {
                        _items.removeWhere((e) => e['id'] == id);
                        _selectedIds.remove(id);
                      });
                    },
                    child: GestureDetector(
                      onLongPress: () {
                        if (!_selectionMode) _enterSelectionMode(id);
                      },
                      onTap: () {
                        if (_selectionMode) _toggleSelection(id);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF455A64).withOpacity(0.15)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? const Color(0xFF455A64) : Colors.grey[200]!,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_selectionMode)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Icon(
                                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: selected ? const Color(0xFF455A64) : Colors.grey,
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(8),
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  color: _colorForType(type).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(_iconForType(type), color: _colorForType(type), size: 20),
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          n['title'] as String? ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                      Text(
                                        _formatTime(d),
                                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  _highlightedBody(n),
                                ],
                              ),
                            ),
                            if (!_selectionMode)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () => _deleteSingle(id, loc),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ];
          }).toList(),
        ),
      ),
    );
  }
}
