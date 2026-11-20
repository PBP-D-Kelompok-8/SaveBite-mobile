import 'package:flutter/material.dart';
import 'package:savebite_mobile/widgets/left_drawer.dart';

class ResepKomunitasPage extends StatelessWidget {
  const ResepKomunitasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resep Komunitas'),
      ),

      drawer: const LeftDrawer(),

      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.menu_book_rounded, size: 64),
              SizedBox(height: 16),
              Text(
                'Resep Komunitas',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Jelajahi Resep, ubah bahan yang tersisa jadi hidangan istimewa.',
                textAlign: TextAlign.center,
              ),

            ],
          ),
        ),
      ),
    );
  }
}
