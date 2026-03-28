import 'package:flutter/material.dart';

class WeatherCard extends StatelessWidget {
  final String location;
  const WeatherCard({super.key, required this.location});

  @override
  Widget build(BuildContext context) {
    // Mock data
    const temp = "29°C";
    const humidity = "78%";
    const waterTemp = "28°C";
    const wind = "12 km";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF4FC3F7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(location,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(temp,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold)),
                  const Text("Sunny",
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
              Icon(Icons.wb_sunny_rounded,
                  color: Colors.white.withOpacity(0.3), size: 64),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _weatherStat("HUMIDITY", humidity),
              _weatherStat("WATER", waterTemp),
              _weatherStat("WIND", wind),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weatherStat(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}
