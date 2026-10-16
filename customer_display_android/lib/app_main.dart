import 'package:flutter/material.dart';

import 'customer_display_page.dart';

void runCustomerDisplayApp() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CustomerDisplayApp());
}

class CustomerDisplayApp extends StatelessWidget {
  const CustomerDisplayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SELFX QR Connect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF34D399),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AndroidCustomerDisplayPage(),
    );
  }
}
