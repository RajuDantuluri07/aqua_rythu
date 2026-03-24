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
  late final int _totalTrays; 
  
  // Data Collection
  bool _isSupplementStep = false;
  final List<TrayStatus> _results = [];
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
      if (mode == FeedMode.precision) {
        // Move to Supplements Step
        setState(() {
          _isSupplementStep = true;
          _selectedStatus = null; 
          _selectedObservations.clear();
        });
      } else {
        _finishAndSave();
      }
    }
  }

  void _finishAndSave() {
    final observationMap = _observations.map((key, value) {
      return MapEntry(key, value.toList());
    });

    final log = TrayLog(
      pondId: widget.pondId,
      time: DateTime.now(),
      doc: widget.doc,
      round: widget.round,
      trays: List.from(_results),
      observations: observationMap.isNotEmpty ? observationMap : null,
      supplements: _selectedSupplements.isNotEmpty ? _selectedSupplements.toList() : null,
    );

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

    // Progress bar calculations
    int totalSteps = _totalTrays + (showSupplements ? 1 : 0);
    int currentStep = _isSupplementStep ? _totalTrays + 1 : currentTrayNumber;
    double progress = currentStep / totalSteps;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Round ${widget.round} Tray Check",
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Linear Progress Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isSupplementStep ? "Supplements" : "Tray $currentTrayNumber of $_totalTrays",
                        style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).primaryColor, fontSize: 16),
                      ),
                      Text(
                        "Step $currentStep of $totalSteps",
                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _isSupplementStep ? _buildSupplementView() : [
                    const Text(
                      "What is the feed status in this tray?",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 20),
                    
                    // Status Options
                    ...TrayStatus.values.map((status) {
                      final isSelected = _selectedStatus == status;
                      return _buildStatusCard(status, isSelected);
                    }),

                    const SizedBox(height: 32),

                    // Observations
                    Row(
                      children: [
                        Icon(Icons.visibility_rounded, size: 18, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'OBSERVATIONS (OPTIONAL)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade600,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
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
                          backgroundColor: Colors.white,
                          selectedColor: Theme.of(context).primaryColor.withOpacity(0.1),
                          checkmarkColor: Theme.of(context).primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                            )
                          ),
                          labelStyle: TextStyle(
                            color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    offset: const Offset(0, -4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: canProceed ? _handleNext : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    elevation: canProceed ? 4 : 0,
                    shadowColor: Theme.of(context).primaryColor.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
          ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.medical_services_rounded, color: Colors.purple.shade400, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Did you apply any supplements?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _supplementOptions.map((option) {
                final isSelected = _selectedSupplements.contains(option);
                return FilterChip(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  backgroundColor: Colors.grey.shade50,
                  selectedColor: Colors.purple.shade50,
                  checkmarkColor: Colors.purple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? Colors.purple.shade200 : Colors.grey.shade200,
                    )
                  ),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.purple.shade700 : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      )
    ];
  }

  Widget _buildStatusCard(TrayStatus status, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedStatus = status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            if (isSelected) BoxShadow(color: status.color.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))
            else BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))
          ],
          border: Border.all(
            color: isSelected ? status.color : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? status.color : status.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                status.icon,
                color: isSelected ? Colors.white : status.color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.black87 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: status.color,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }
}