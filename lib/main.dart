import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:savebite_mobile/request_board/providers/request_board_provider.dart';
import 'package:savebite_mobile/request_board/services/request_board_service.dart';
import 'package:savebite_mobile/request_board/services/session_client.dart';
import 'package:savebite_mobile/widgets/left_drawer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SaveBiteSessionClient>(
          create: (_) => SaveBiteSessionClient(),
        ),
        ProxyProvider<SaveBiteSessionClient, RequestBoardService>(
          update: (_, sessionClient, _) => RequestBoardService(
            sessionClient: sessionClient,
          ),
        ),
        ChangeNotifierProxyProvider<RequestBoardService, RequestBoardProvider>(
          create: (context) => RequestBoardProvider(
            service: context.read<RequestBoardService>(),
          ),
          update: (_, service, previous) =>
              previous ?? RequestBoardProvider(service: service),
        ),
      ],
      child: MaterialApp(
        title: 'SaveBite',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
          useMaterial3: true,
        ),
        home: const MyHomePage(title: 'SaveBite'),
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      drawer: const LeftDrawer(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'SaveBite: Food Waste Management',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Aplikasi mobile penanggulangan pemborosan makanan (food waste) yang membantu pengguna memaksimalkan pemanfaatan bahan makanan melalui rencana penyelamatan makanan, pencarian resep darurat berbahan sisa, hingga ruang komunitas untuk saling berbagi resep dan sisa bahan makanan.',
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
