import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_helpers.dart';

class InfoCard extends StatelessWidget {
  final String title;
  final String description;
  final String? footer;
  final Color? footerColor;
  final VoidCallback? onTap;

  const InfoCard({
    super.key,
    required this.title,
    required this.description,
    this.footer,
    this.footerColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: defaultCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 12),
            Text(
              footer!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: footerColor ?? AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return cardContent;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: cardContent,
    );
  }
}
