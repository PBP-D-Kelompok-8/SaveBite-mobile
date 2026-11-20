import 'package:flutter/material.dart';
import 'package:savebite_mobile/widgets/left_drawer.dart';

class KatalogPage extends StatelessWidget {
  const KatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Katalog Resep Bahan Sisa'),
      ),
      drawer: const LeftDrawer(),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.restaurant_rounded, size: 64),
              SizedBox(height: 16),
              Text(
                'Katalog Resep Bahan Sisa',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Temukan inspirasi resep dari bahan makanan yang masih tersedia.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
