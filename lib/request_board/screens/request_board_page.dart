import 'package:flutter/material.dart';
import 'package:savebite_mobile/widgets/left_drawer.dart';

class RequestBoardPage extends StatelessWidget {
  const RequestBoardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Rescue Request Board'),
      ),
      drawer: const LeftDrawer(),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.forum_rounded, size: 64),
              SizedBox(height: 16),
              Text(
                'Food Rescue Request Board',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Papan permintaan bahan makanan sisa untuk komunitas lokal.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
