import 'package:flutter/material.dart';

void main() => runApp(const IslandDeskApp());

class IslandDeskApp extends StatelessWidget {
  const IslandDeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(child: Text('IslandDesk development shell')),
      ),
    );
  }
}

