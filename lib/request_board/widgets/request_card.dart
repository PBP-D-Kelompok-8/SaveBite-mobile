import 'package:flutter/material.dart';
import 'package:savebite_mobile/request_board/models/food_request.dart';

/// Mengembalikan label bahasa Indonesia untuk nilai `effectiveStatus`.
String requestStatusLabel(String effectiveStatus) {
  switch (effectiveStatus) {
    case 'pending':
      return 'Pending';
    case 'offered':
      return 'Ditawarkan';
    case 'fulfilled':
      return 'Terpenuhi';
    case 'expired':
      return 'Kedaluwarsa';
    default:
      return effectiveStatus;
  }
}

/// Tag [Hero] konsisten untuk transisi dari [RequestCard] ke halaman detail.
String requestCardHeroTag(int requestId) => 'request-card-hero-$requestId';

/// Badge status beranimasi untuk `effectiveStatus` pada [FoodRequest].
class RequestStatusBadge extends StatelessWidget {
  final String effectiveStatus;

  const RequestStatusBadge({
    super.key,
    required this.effectiveStatus,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (Color backgroundColor, Color foregroundColor) = switch (
      effectiveStatus
    ) {
      'pending' => (
          colorScheme.secondaryContainer,
          colorScheme.onSecondaryContainer,
        ),
      'offered' => (
          colorScheme.tertiaryContainer,
          colorScheme.onTertiaryContainer,
        ),
      'fulfilled' => (
          colorScheme.primaryContainer,
          colorScheme.onPrimaryContainer,
        ),
      'expired' => (
          colorScheme.errorContainer,
          colorScheme.onErrorContainer,
        ),
      _ => (
          colorScheme.surfaceContainerHighest,
          colorScheme.onSurfaceVariant,
        ),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        requestStatusLabel(effectiveStatus),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// Kartu interaktif untuk menampilkan ringkasan satu [FoodRequest] di board.
class RequestCard extends StatelessWidget {
  final FoodRequest request;
  final VoidCallback? onTap;

  const RequestCard({
    super.key,
    required this.request,
    this.onTap,
  });

  String _formatQuantity(String raw) {
    final parsed = double.tryParse(raw);
    if (parsed == null) return raw;
    if (parsed == parsed.roundToDouble()) {
      return parsed.toInt().toString();
    }
    return parsed.toString().replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _formatExpiresAt(DateTime? expiresAt) {
    if (expiresAt == null) return 'Tanpa tenggat';
    final local = expiresAt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Hero(
                tag: requestCardHeroTag(request.id),
                child: Material(
                  type: MaterialType.transparency,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          request.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      RequestStatusBadge(
                        effectiveStatus: request.effectiveStatus,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _InfoChip(
                    icon: Icons.restaurant_outlined,
                    label: request.foodItem,
                  ),
                  _InfoChip(
                    icon: Icons.scale_outlined,
                    label:
                        '${_formatQuantity(request.quantity)} ${request.unit}',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _MetaRow(
                icon: Icons.location_on_outlined,
                text: request.location.isNotEmpty
                    ? request.location
                    : 'Lokasi belum ditentukan',
              ),
              const SizedBox(height: 4),
              _MetaRow(
                icon: Icons.person_outline,
                text: request.owner.displayName,
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.volunteer_activism_outlined,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${request.offerCount} penawaran',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.schedule_outlined,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _formatExpiresAt(request.expiresAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
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
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
