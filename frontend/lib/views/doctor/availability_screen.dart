import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/doctor_service.dart';
import '../../models/availability_model.dart';

class DoctorAvailabilityScreen extends StatefulWidget {
  const DoctorAvailabilityScreen({super.key});

  @override
  State<DoctorAvailabilityScreen> createState() => _DoctorAvailabilityScreenState();
}

class _DoctorAvailabilityScreenState extends State<DoctorAvailabilityScreen> {
  final DoctorService _doctorService = DoctorService();
  bool _isLoading = true;
  bool _isSaving = false;
  
  List<AvailabilityModel> _availabilities = [];
  final List<String> _days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    final user = AuthService().currentUser;
    if (user != null) {
      final data = await _doctorService.getAvailability(user.id);
      setState(() {
        _availabilities = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAvailability() async {
    setState(() => _isSaving = true);
    try {
      final user = AuthService().currentUser;
      if (user != null) {
        await _doctorService.updateAvailability(user.id, _availabilities);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Availability updated')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _toggleDay(int dayIndex) {
    setState(() {
      final existingIndex = _availabilities.indexWhere((a) => a.dayOfWeek == dayIndex);
      if (existingIndex != -1) {
        _availabilities.removeAt(existingIndex);
      } else {
        _availabilities.add(AvailabilityModel(
          doctorId: AuthService().currentUser!.id,
          dayOfWeek: dayIndex,
          startTime: '09:00:00',
          endTime: '17:00:00',
        ));
      }
    });
  }

  Future<void> _selectTime(int dayIndex, bool isStart) async {
    final existingIndex = _availabilities.indexWhere((a) => a.dayOfWeek == dayIndex);
    if (existingIndex == -1) return;

    final initialTime = isStart 
        ? TimeOfDay(hour: int.parse(_availabilities[existingIndex].startTime.split(':')[0]), minute: 0)
        : TimeOfDay(hour: int.parse(_availabilities[existingIndex].endTime.split(':')[0]), minute: 0);

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      setState(() {
        final timeStr = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00';
        final old = _availabilities[existingIndex];
        _availabilities[existingIndex] = AvailabilityModel(
          doctorId: old.doctorId,
          dayOfWeek: old.dayOfWeek,
          startTime: isStart ? timeStr : old.startTime,
          endTime: isStart ? old.endTime : timeStr,
          slotDurationMinutes: old.slotDurationMinutes,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text('Weekly Schedule', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: [
          if (_isSaving)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ))
          else
            TextButton(
              onPressed: _saveAvailability,
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final isEnabled = _availabilities.any((a) => a.dayOfWeek == index);
          final availability = isEnabled ? _availabilities.firstWhere((a) => a.dayOfWeek == index) : null;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isEnabled ? const Color(0xFF1B3C40) : Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _days[index],
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: isEnabled ? const Color(0xFF1B3C40) : Colors.grey[600],
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: isEnabled,
                      activeColor: const Color(0xFF1B3C40),
                      onChanged: (_) => _toggleDay(index),
                    ),
                  ],
                ),
                if (isEnabled) ...[
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTimeSelector('Start', availability!.startTime.substring(0, 5), () => _selectTime(index, true)),
                      const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                      _buildTimeSelector('End', availability.endTime.substring(0, 5), () => _selectTime(index, false)),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeSelector(String label, String time, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              time,
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
