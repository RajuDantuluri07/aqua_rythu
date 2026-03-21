import 'package:flutter/material.dart';

class HarvestScreen extends StatelessWidget {
  final String pondId;
  const HarvestScreen({super.key, required this.pondId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Harvest")),
      body: const Center(child: Text("Harvest Feature Coming Soon")),
    );
  }
}