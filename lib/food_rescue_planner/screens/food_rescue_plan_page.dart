import 'package:flutter/material.dart';

import '../models/food_rescue_plan.dart';
import '../widgets/food_rescue_plan_card.dart';

class FoodRescuePlanPage extends StatefulWidget {
  const FoodRescuePlanPage({super.key});

  @override
  State<FoodRescuePlanPage> createState() =>
      _FoodRescuePlanPageState();
}

class _FoodRescuePlanPageState
    extends State<FoodRescuePlanPage> {
  final List<FoodRescuePlan> _plans = [
    FoodRescuePlan(
      id: 1,
      namaBahan: 'Apel',
      jumlah: 5,
      satuan: 'pcs',
      targetDate: DateTime.now().add(
        const Duration(days: 2),
      ),
      metodeAksi: 'cook',
      status: 'ongoing',
      notes: 'Gunakan untuk membuat apple pie.',
    ),
    FoodRescuePlan(
      id: 2,
      namaBahan: 'Bayam',
      jumlah: 200,
      satuan: 'gr',
      targetDate: DateTime.now(),
      metodeAksi: 'share',
      status: 'success',
      notes: 'Dibagikan kepada tetangga.',
    ),
  ];

  Future<void> _showPlanForm({FoodRescuePlan? plan}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: plan?.namaBahan ?? '',
    );
    final quantityController = TextEditingController(
      text: plan?.jumlah.toString() ?? '1',
    );
    final notesController = TextEditingController(
      text: plan?.notes ?? '',
    );

    String selectedUnit = plan?.satuan ?? 'pcs';
    String selectedAction = plan?.metodeAksi ?? 'cook';
    DateTime selectedDate =
        plan?.targetDate ?? DateTime.now();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                plan == null ? 'Create Plan' : 'Edit Plan',
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Food Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Food name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final quantity =
                              int.tryParse(value ?? '');
                          if (quantity == null ||
                              quantity <= 0) {
                            return 'Enter a valid quantity';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedUnit,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'kg',
                            child: Text('Kilogram'),
                          ),
                          DropdownMenuItem(
                            value: 'gr',
                            child: Text('Gram'),
                          ),
                          DropdownMenuItem(
                            value: 'pcs',
                            child: Text('Pieces'),
                          ),
                          DropdownMenuItem(
                            value: 'porsi',
                            child: Text('Porsi'),
                          ),
                          DropdownMenuItem(
                            value: 'liter',
                            child: Text('Liter'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedUnit = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedAction,
                        decoration: const InputDecoration(
                          labelText: 'Action Method',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'cook',
                            child: Text('Cook'),
                          ),
                          DropdownMenuItem(
                            value: 'preserve',
                            child: Text('Preserve'),
                          ),
                          DropdownMenuItem(
                            value: 'share',
                            child: Text('Share'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedAction = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Target Date'),
                        subtitle: Text(
                          '${selectedDate.day}/'
                          '${selectedDate.month}/'
                          '${selectedDate.year}',
                        ),
                        trailing: const Icon(
                          Icons.calendar_month,
                        ),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );

                          if (date != null) {
                            setDialogState(() {
                              selectedDate = date;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes (Optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    setState(() {
                      if (plan == null) {
                        final nextId = _plans.isEmpty
                            ? 1
                            : _plans
                                    .map((item) => item.id)
                                    .reduce(
                                      (a, b) => a > b ? a : b,
                                    ) +
                                1;

                        _plans.insert(
                          0,
                          FoodRescuePlan(
                            id: nextId,
                            namaBahan:
                                nameController.text.trim(),
                            jumlah: int.parse(
                              quantityController.text,
                            ),
                            satuan: selectedUnit,
                            targetDate: selectedDate,
                            metodeAksi: selectedAction,
                            status: 'ongoing',
                            notes: notesController.text.trim(),
                          ),
                        );
                      } else {
                        final index = _plans.indexWhere(
                          (item) => item.id == plan.id,
                        );

                        if (index != -1) {
                          _plans[index] = FoodRescuePlan(
                            id: plan.id,
                            namaBahan:
                                nameController.text.trim(),
                            jumlah: int.parse(
                              quantityController.text,
                            ),
                            satuan: selectedUnit,
                            targetDate: selectedDate,
                            metodeAksi: selectedAction,
                            status: plan.status,
                            notes: notesController.text.trim(),
                            createdAt: plan.createdAt,
                            completedAt: plan.completedAt,
                          );
                        }
                      }
                    });

                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    quantityController.dispose();
    notesController.dispose();
  }

  Future<void> _deletePlan(FoodRescuePlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plan?'),
        content: Text(
          'Are you sure you want to delete ${plan.namaBahan}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _plans.removeWhere((item) => item.id == plan.id);
      });
    }
  }

  Future<void> _updateStatus(FoodRescuePlan plan) async {
    final selectedStatus = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Mark as Success'),
              leading: const Icon(
                Icons.check_circle,
                color: Colors.green,
              ),
              onTap: () => Navigator.pop(context, 'success'),
            ),
            ListTile(
              title: const Text('Mark as Failed'),
              leading: const Icon(
                Icons.cancel,
                color: Colors.red,
              ),
              onTap: () => Navigator.pop(context, 'failed'),
            ),
          ],
        ),
      ),
    );

    if (selectedStatus != null) {
      setState(() {
        final index = _plans.indexWhere(
          (item) => item.id == plan.id,
        );

        if (index != -1) {
          _plans[index] = FoodRescuePlan(
            id: plan.id,
            namaBahan: plan.namaBahan,
            jumlah: plan.jumlah,
            satuan: plan.satuan,
            targetDate: plan.targetDate,
            metodeAksi: plan.metodeAksi,
            status: selectedStatus,
            notes: plan.notes,
            createdAt: plan.createdAt,
            completedAt: DateTime.now(),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Food Rescue Planner',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _plans.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.eco_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No rescue plans yet.',
                    style: TextStyle(fontSize: 16),
                  ),
                  Text('Create your first plan!'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Manage Your Food',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Plan how to use your ingredients '
                  'and reduce food waste.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildSummary(
                      'Total Plans',
                      _plans.length.toString(),
                      Colors.blue,
                    ),
                    const SizedBox(width: 10),
                    _buildSummary(
                      'Ongoing',
                      _plans
                          .where((p) => p.status == 'ongoing')
                          .length
                          .toString(),
                      Colors.orange,
                    ),
                    const SizedBox(width: 10),
                    _buildSummary(
                      'Success',
                      _plans
                          .where((p) => p.status == 'success')
                          .length
                          .toString(),
                      Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'My Rescue Plans',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ..._plans.map(
                  (plan) => FoodRescuePlanCard(
                    plan: plan,
                    onEdit: () => _showPlanForm(plan: plan),
                    onDelete: () => _deletePlan(plan),
                    onStatusChange: () => _updateStatus(plan),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPlanForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Plan'),
      ),
    );
  }

  Widget _buildSummary(
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}