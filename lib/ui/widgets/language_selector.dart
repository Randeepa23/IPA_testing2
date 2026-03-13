// lib/widgets/language_selector.dart

import 'package:flutter/material.dart';
import '../../Models/language_model.dart';

class LanguageSelectorSheet extends StatefulWidget {
  final AppLanguage selected;
  final Function(AppLanguage) onSelected;
  final String title;
  final bool includeAutoDetect;


  const LanguageSelectorSheet({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.title,
    this.includeAutoDetect = false, // ← new flag to include "Auto Detect" option
  });

    static Future<void> show(
      BuildContext context, {
      required AppLanguage selected,
      required Function(AppLanguage) onSelected,
      required String title,
      bool includeAutoDetect = false, // ← add this
    }) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => LanguageSelectorSheet(
          selected: selected,
          onSelected: onSelected,
          title: title,
          includeAutoDetect: includeAutoDetect, // ← pass it
        ),
      );
    }

  @override
  State<LanguageSelectorSheet> createState() => _LanguageSelectorSheetState();
}

class _LanguageSelectorSheetState extends State<LanguageSelectorSheet> {
  String _search = '';

List<AppLanguage> get filtered {
  final base = widget.includeAutoDetect // ← add widget.
      ? [kAutoDetect, ...kLanguages]  // ← prepend auto detect
      : kLanguages;

  if (_search.isEmpty) return base;
  return base
      .where((l) =>
          l.name.toLowerCase().contains(_search.toLowerCase()) ||
          l.nativeName.toLowerCase().contains(_search.toLowerCase()))
      .toList();
}

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search language...',
                  hintStyle: TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Language list
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final lang = filtered[i];
                  final isSelected = lang.code == widget.selected.code;
                  return ListTile(
                    onTap: () {
                      widget.onSelected(lang);
                      Navigator.pop(context);
                    },
                    leading: Text(lang.flag, style: const TextStyle(fontSize: 28)),
                    title: Text(
                      lang.name,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF4FC3F7) : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      lang.nativeName,
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!lang.offlineSupported)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.orange.withOpacity(0.5)),
                            ),
                            child: const Text(
                              'Online',
                              style: TextStyle(color: Colors.orange, fontSize: 10),
                            ),
                          ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle, color: Color(0xFF4FC3F7), size: 20),
                        ],
                      ],
                    ),
                    tileColor: isSelected ? Colors.white.withOpacity(0.05) : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}