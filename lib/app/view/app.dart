import 'package:flutter/material.dart';
import '../../features/parches/view/home_parches_page.dart';

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parches',
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange)),
      home: HomeParchesPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}