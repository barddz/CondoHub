import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_helpers.dart';

class InfoCard extends StatelessWidget {
  final String title;
  final String description;
  final String? footer;
  final Color? footerColor;
  final VoidCallback? onTap;
  final Widget? action;
  final Widget? badge;
  final IconData? leadingIcon;

  const InfoCard({
    super.key,
    required this.title,
    required this.description,
    this.footer,
    this.footerColor,
    this.onTap,
    this.action,
    this.badge,
    this.leadingIcon,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leadingIcon != null) ...[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(leadingIcon, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
              ],
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
              if (badge != null) ...[
                const SizedBox(width: 12),
                badge!,
              ],
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
          if (action != null) ...[
            const SizedBox(height: 12),
            action!,
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
