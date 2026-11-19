import 'package:flutter/material.dart';
import '../widgets/left_drawer.dart';

class JurnalPage extends StatelessWidget {
  const JurnalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jurnal Jejak Makanan')),
      drawer: const LeftDrawer(),
      body: const Center(child: Text('Halaman Modul Jurnal Jejak Makanan')),
    );
  }
}