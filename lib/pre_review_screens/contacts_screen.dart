import 'dart:io';

import 'package:flutter/material.dart';
import 'package:smart_printer/config/pro_theme.dart';
import '../l10n/labels.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:path_provider/path_provider.dart';
import '../ads/ad_service.dart';
import '../database/data-base.dart';
import '../models/print_history_model.dart';
import 'text_pre.dart';
import '../widgets/app_loader.dart';
import '../widgets/app_snack.dart';
import '../widgets/pro_crown_icon.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
  List<Contact> _contacts = [];
  List<Contact> _filtered = [];
  bool _loading = true;
  bool _saving = false;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _loading = true;
      _permissionDenied = false;
    });
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        if (!mounted) return;
        setState(() {
          _permissionDenied = true;
        });
        return;
      }
      final items = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );
      if (!mounted) return;
      setState(() {
        _contacts = items;
        _filtered = items;
      });
    } catch (error) {
      debugPrint('Contacts load failed: $error');
      if (mounted) {
        AppSnack.show(context, t(context, 'could_not_load_contacts', namedArgs: {'error': '$error'}));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filtered = _contacts);
      return;
    }
    setState(() {
      _filtered = _contacts.where((c) {
        final name = c.displayName.toLowerCase();
        final phone = c.phones.isNotEmpty ? c.phones.first.number : '';
        return name.contains(query) || phone.contains(query);
      }).toList();
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    final selectable =
        _contacts.where((c) => c.phones.isNotEmpty).map((c) => c.id).toList();
    final allSelected =
        selectable.isNotEmpty && selectable.every(_selectedIds.contains);
    setState(() {
      if (allSelected) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(selectable);
      }
    });
  }

  void _printSelected() {
    final selected = _contacts.where((c) => _selectedIds.contains(c.id));
    final buffer = StringBuffer();
    for (final c in selected) {
      if (c.phones.isEmpty) continue;
      for (final p in c.phones) {
        buffer.writeln('${c.displayName} - ${p.number}');
      }
    }
    final text = buffer.toString().trim();
    if (text.isEmpty) {
      AppSnack.show(context, t(context, 'select_contacts_phone'));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TextPreScreen(initialText: text),
      ),
    );
  }

  Future<void> _saveSelected() async {
    final selected = _contacts.where((c) => _selectedIds.contains(c.id));
    final buffer = StringBuffer();
    for (final c in selected) {
      if (c.phones.isEmpty) continue;
      for (final p in c.phones) {
        buffer.writeln('${c.displayName} - ${p.number}');
      }
    }
    final text = buffer.toString().trim();
    if (text.isEmpty) {
      AppSnack.show(context, t(context, 'select_contacts_phone'));
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final Directory dir;
      if (Platform.isAndroid) {
        final external = await getExternalStorageDirectory();
        dir = external ?? await getApplicationDocumentsDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      await dir.create(recursive: true);
      final file = File(
        '${dir.path}/contacts_${DateTime.now().millisecondsSinceEpoch}.txt',
      );
      await file.writeAsString(text, flush: true);
      await HistoryDB.instance.insertHistory(
        PrintHistory(
          title: 'Contacts',
          type: 'file',
          filePath: file.path,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      if (!mounted) return;
      AppSnack.show(context, t(context, 'saved_to_files'));
    } catch (error) {
      debugPrint('Contacts save failed: $error');
      if (!mounted) return;
      AppSnack.show(context, t(context, 'could_not_save_contacts'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBusyOverlay(
      busy: _loading || _saving,
      message: _loading ? t(context, 'loading_contacts') : t(context, 'saving'),
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF2B3A55),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          t(context, 'feat_contacts'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2B3A55),
          ),
        ),
        actions: [
          const ProAppBarButton(),
          IconButton(
            onPressed: _loadContacts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: _HeaderCard(
              count: _contacts.length,
              selected: _selectedIds.length,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: t(context, 'search_contacts'),
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _toggleSelectAll,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2B3A55),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    t(context, 'select_all'),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _permissionDenied
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t(context, 'contacts_denied'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _loadContacts,
                              icon: const Icon(Icons.refresh),
                              label: Text(t(context, 'try_again')),
                            ),
                          ],
                        ),
                      )
                    : _filtered.isEmpty
                        ? Center(
                            child: Text(
                              t(context, 'no_contacts'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final contact = _filtered[index];
                          final hasPhone = contact.phones.isNotEmpty;
                          final isSelected =
                              _selectedIds.contains(contact.id);
                          return _ContactTile(
                            contact: contact,
                            enabled: hasPhone,
                            selected: isSelected,
                            onTap: hasPhone
                                ? () => _toggleSelect(contact.id)
                                : null,
                          );
                        },
                      ),
          ),
          _BottomActions(
            onSave: _loading || _saving
                ? () {}
                : afterInterstitial(_saveSelected),
            onPrint: _loading || _saving
                ? () {}
                : () {
                    AdService.instance.showInterstitialThen(() async {
                      _printSelected();
                    });
                  },
          ),
        ],
      ),
    ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.count, required this.selected});

  final int count;
  final int selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.contacts_rounded,
              color: AppTheme.actionColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t(context, 'contacts_summary', namedArgs: {
                'count': '$count',
                'selected': '$selected',
              }),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2B3A55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final Contact contact;
  final bool enabled;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: enabled
                    ? const Color(0xFFEAF6FF)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: AppTheme.actionColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: enabled
                          ? const Color(0xFF2B3A55)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    phone.isEmpty ? t(context, 'no_number') : phone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7B8BA6),
                    ),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: selected,
              onChanged: enabled ? (_) => onTap?.call() : null,
              activeColor: AppTheme.actionColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.onSave, required this.onPrint});

  final VoidCallback onSave;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_rounded, size: 20),
                label: Text(
                  t(context, 'save'),
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2B3A55),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onPrint,
                icon: const Icon(Icons.print_rounded, size: 20),
                label: Text(
                  t(context, 'print_selected'),
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.actionColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
