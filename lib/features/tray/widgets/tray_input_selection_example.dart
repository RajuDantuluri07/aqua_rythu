import 'package:flutter/material.dart';
import '../enums/tray_status.dart';
import '../../../systems/feed/tray_factor_service.dart';
import 'tray_input_selection.dart';

/// Example usage of the TrayInputSelection component
///
/// This demonstrates how to integrate the tray input component
/// into a screen with validation and submission handling.
class TrayInputSelectionExample extends StatefulWidget {
  const TrayInputSelectionExample({super.key});

  @override
  State<TrayInputSelectionExample> createState() =>
      _TrayInputSelectionExampleState();
}

class _TrayInputSelectionExampleState extends State<TrayInputSelectionExample> {
  TrayStatus? _selectedState;
  final TrayFactorService _trayFactorService = TrayFactorService();

  void _handleSubmit() {
    if (_selectedState == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a tray status'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Get the adjustment factor from TrayFactorService (not from UI)
    final factor = _trayFactorService.getFactor(_selectedState!);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected: ${_selectedState!.label} (Factor: $factor)'),
        backgroundColor: _selectedState!.color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Tray Input Example',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tray Status Check',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Round 1 - Tray 1 of 4',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),

              // The tray input selection component
              TrayInputSelection(
                selectedState: _selectedState,
                onSelectionChanged: (state) {
                  setState(() {
                    _selectedState = state;
                  });
                },
              ),

              const Spacer(),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _selectedState?.color ?? Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    elevation: _selectedState != null ? 4 : 0,
                    shadowColor: _selectedState?.color.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
