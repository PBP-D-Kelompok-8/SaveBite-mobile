import 'package:flutter/material.dart';

import '../models/food_rescue_plan.dart';

class FoodRescuePlanCard extends StatelessWidget {
  final FoodRescuePlan plan;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onStatusChange;

  const FoodRescuePlanCard({
    super.key,
    required this.plan,
    this.onEdit,
    this.onDelete,
    this.onStatusChange,
  });

  Color get statusColor {
    switch (plan.status) {
      case 'success':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String get statusLabel {
    switch (plan.status) {
      case 'success':
        return 'Success';
      case 'failed':
        return 'Failed';
      default:
        return 'Ongoing';
    }
  }

  String get actionLabel {
    switch (plan.metodeAksi) {
      case 'cook':
        return 'Cook';
      case 'preserve':
        return 'Preserve';
      case 'share':
        return 'Share';
      default:
        return plan.metodeAksi;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.namaBahan,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${plan.jumlah} ${plan.satuan}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoChip(
                  Icons.restaurant,
                  actionLabel,
                  Colors.blue,
                ),
                _infoChip(
                  Icons.calendar_today,
                  '${plan.targetDate.day}/'
                  '${plan.targetDate.month}/'
                  '${plan.targetDate.year}',
                  Colors.blueGrey,
                ),
                _infoChip(
                  Icons.circle,
                  statusLabel,
                  statusColor,
                ),
              ],
            ),
            if (plan.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                plan.notes,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
            if (plan.status == 'ongoing') ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onStatusChange,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Update Status'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip(
    IconData icon,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}