import 'package:flutter/material.dart';

import '../core/app_helpers.dart';

class ListCategoryFilter extends StatelessWidget {
  final String selectedValue;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final String label;

  const ListCategoryFilter({
    super.key,
    required this.selectedValue,
    required this.options,
    required this.onChanged,
    this.label = 'Filtrar por status',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: defaultCardDecoration(),
      child: DropdownButtonFormField<String>(
        value: selectedValue,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.filter_list),
          border: const OutlineInputBorder(),
        ),
        items: options
            .map(
              (option) => DropdownMenuItem(
                value: option,
                child: Text(option, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
