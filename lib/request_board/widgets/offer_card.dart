import 'package:flutter/material.dart';
import 'package:savebite_mobile/request_board/models/request_offer.dart';

/// Kartu penawaran bantuan (`RequestOffer`) yang ditampilkan pada halaman
/// detail bagi pemilik permintaan.
class OfferCard extends StatelessWidget {
  final RequestOffer offer;

  /// Penanda terpilih dihitung dari `offer.id == foodRequest.selectedOfferId`
  /// agar selalu sinkron dengan state terbaru permintaan.
  final bool isSelected;

  /// Menunjukkan apakah permintaan sudah memiliki penawar terpilih lain.
  final bool hasAnySelectedOffer;

  /// Menunjukkan apakah tombol pilih/ganti penawar boleh ditekan
  /// (`request.isActive && !isSubmitting`).
  final bool canSelect;

  final bool isSubmitting;
  final VoidCallback? onSelect;

  const OfferCard({
    super.key,
    required this.offer,
    required this.isSelected,
    required this.hasAnySelectedOffer,
    required this.canSelect,
    this.isSubmitting = false,
    this.onSelect,
  });

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
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

    final selectButtonLabel =
        hasAnySelectedOffer ? 'Ganti ke Penawar Ini' : 'Pilih Offer';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.35)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.outlineVariant.withValues(alpha: 0.7),
          width: isSelected ? 1.6 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isSelected
                      ? colorScheme.primary
                      : colorScheme.secondaryContainer,
                  child: Icon(
                    Icons.volunteer_activism_outlined,
                    size: 18,
                    color: isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.offeredBy.displayName.isNotEmpty
                            ? offer.offeredBy.displayName
                            : 'Pengguna #${offer.offeredBy.id}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ditawarkan pada ${_formatDateTime(offer.createdAt)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 14,
                          color: colorScheme.onPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Terpilih',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (!isSelected) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: canSelect && !isSubmitting ? onSelect : null,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.how_to_reg_outlined, size: 18),
                  label: Text(selectButtonLabel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
