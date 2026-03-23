import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/engines/feed_state_engine.dart';
import 'tray_provider.dart';
import 'tray_model.dart';
import '../farm/farm_provider.dart';
import '../../core/enums/tray_status.dart';

class TrayLogScreen extends ConsumerStatefulWidget {
  final String pondId;
  final int doc;
  final int round;
  const TrayLogScreen({super.key, required this.pondId, required this.doc, required this.round});
  @override
  ConsumerState<TrayLogScreen> createState() => _TrayLogScreenState();
}

class _TrayLogScreenState extends ConsumerState<TrayLogScreen> {
  // Wizard State
  int _currentTrayIndex = 0; // 0-based
  late final int _totalTrays; // Should be fetched from pond data
  
  // Data Collection
  bool _isSupplementStep = false;
  final List<TrayStatus> _results = [];
  // We track observations but V1 provider might not save them yet
  // Keeping them in state for future use or local logic
  final Map<int, Set<String>> _observations = {}; 

  // Current Selection
  TrayStatus? _selectedStatus;
  final Set<String> _selectedObservations = {};
  final Set<String> _selectedSupplements = {};

  final List<String> _supplementOptions = [
    'Probiotic',
    'Mineral Mix',
    'Vitamin C',
    'Gut Pro',
  ];

  final List<String> _observationOptions = [
    'Dead shrimp',
    'Red legs',
    'White gut',
    'Weak feeding',
    'Uneven size',
  ];

  @override
  void initState() {
    super.initState();
    final farmState = ref.read(farmProvider);
    Pond? pond;
    for (final farm in farmState.farms) {
      try {
        pond = farm.ponds.firstWhere((p) => p.id == widget.pondId);
        if (pond != null) break;
      } catch (_) {}
    }
    _totalTrays = pond?.numTrays ?? 4;
  }

  void _handleNext() {
    if (_isSupplementStep) {
      // This entire block should only be reachable if supplements are enabled
      // The button text and action should change to _finishAndSave directly
      // if supplements are not part of the flow.
      _finishAndSave();
      return;
    }

    if (_selectedStatus == null) return;

    // Save current step data
    _results.add(_selectedStatus!);
    _observations[_currentTrayIndex] = Set.from(_selectedObservations);

    if (_results.length < _totalTrays) {
      // Move to next tray
      setState(() {
        _currentTrayIndex++;
        _selectedStatus = null;
        _selectedObservations.clear();
      });
    } else { // Last tray has been logged
      final mode = FeedStateEngine.getMode(widget.doc);
      // Per PRD 5.6.3, only show supplements in Precision mode
      if (mode == FeedMode.precision) {
      // Move to Supplements Step
      setState(() {
        _isSupplementStep = true;
        _selectedStatus = null; // Clear selection for safety
        _selectedObservations.clear();
      });
      } else {
        // Otherwise, finish immediately
        _finishAndSave();
      }
    }
  }

  void _finishAndSave() {
    final observationMap = _observations.map((key, value) {
      return MapEntry(key, value.toList());
    });

    // ✅ CREATE LOG OBJECT
    final log = TrayLog(
      pondId: widget.pondId,
      time: DateTime.now(),
      doc: widget.doc,
      round: widget.round,
      trays: List.from(_results),
      observations: observationMap.isNotEmpty ? observationMap : null,
      supplements: _selectedSupplements.isNotEmpty
          ? _selectedSupplements.toList()
          : null,
    );

    // ✅ SAVE TO PROVIDER
    ref.read(trayProvider(widget.pondId).notifier).addTrayLog(log);
    
    Navigator.pop(context, "Logged $_totalTrays trays");
  }

  @override
  Widget build(BuildContext context) {
    final currentTrayNumber = _currentTrayIndex + 1;
    final isLastTrayStep = currentTrayNumber == _totalTrays && !_isSupplementStep;
    final canProceed = _isSupplementStep ? true : _selectedStatus != null;
    final feedMode = FeedStateEngine.getMode(widget.doc);
    final showSupplements = feedMode == FeedMode.precision;


    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Log Feed Check',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isSupplementStep ? 'Add Supplements' : 'Round ${widget.round}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  Chip(
                    label: Text(
                      _isSupplementStep 
                          ? 'Final Step' 
                          : 'Tray $currentTrayNumber of $_totalTrays',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                    ),
                    backgroundColor: Colors.black,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _isSupplementStep ? _buildSupplementView() : [
                    // Status Options
                    ...TrayStatus.values.map((status) {
                      final isSelected = _selectedStatus == status;
                      return _buildStatusCard(status, isSelected);
                    }),

                    const SizedBox(height: 24),

                    // Observations
                    Text(
                      'OBSERVATIONS (OPTIONAL)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _observationOptions.map((obs) {
                        final isSelected = _selectedObservations.contains(obs);
                        return FilterChip(
                          label: Text(obs),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedObservations.add(obs);
                              } else {
                                _selectedObservations.remove(obs);
                              }
                            });
                          },
                          selectedColor: Colors.blue.shade100,
                          checkmarkColor: Colors.blue,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.blue.shade900 : Colors.black87,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // Sticky Bottom Button
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: canProceed ? _handleNext : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _isSupplementStep
                        ? 'Save All & Finish'
                        : (isLastTrayStep
                            ? (showSupplements ? 'Next: Add Supplements →' : 'Save & Finish')
                            : 'Next: Tray ${currentTrayNumber + 1} →'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSupplementView() {
    return [
      const Text(
        'Did you use any supplements in this round?',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _supplementOptions.map((option) {
          final isSelected = _selectedSupplements.contains(option);
          return FilterChip(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            label: Text(option),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  _selectedSupplements.add(option);
                } else {
                  _selectedSupplements.remove(option);
                }
              });
            },
            selectedColor: Colors.green.shade100,
            checkmarkColor: Colors.green.shade800,
            labelStyle: TextStyle(
              color: isSelected ? Colors.green.shade900 : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 15,
            ),
          );
        }).toList(),
      ),
    ];
  }

  Widget _buildStatusCard(TrayStatus status, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedStatus = status),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? status.color.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? status.color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: status.color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                status.icon,
                color: status.color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: status.color,
              ),
          ],
        ),
      ),
    );
  }
}