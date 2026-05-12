import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'booking_flow_screen.dart';

class BookingStatusScreen extends StatefulWidget {
  final String appointmentId;
  final String doctorName;

  const BookingStatusScreen({
    super.key,
    required this.appointmentId,
    required this.doctorName,
  });

  @override
  State<BookingStatusScreen> createState() => _BookingStatusScreenState();
}

class _BookingStatusScreenState extends State<BookingStatusScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  StreamSubscription? _sub;

  Map<String, dynamic>? _appointment;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Load initial state
    _loadAppointment();

    // Realtime stream — updates LIVE when doctor approves
    _sub = _supabase
        .from('appointments')
        .stream(primaryKey: ['id'])
        .eq('id', widget.appointmentId)
        .listen((rows) {
      if (rows.isNotEmpty && mounted) {
        setState(() => _appointment = rows.first);
        if (_appointment?['status'] == 'confirmed') {
          _pulseCtrl.stop();
        }
      }
    });
  }

  Future<void> _loadAppointment() async {
    final res = await _supabase
        .from('appointments')
        .select('*, profiles!doctor_id(full_name)')
        .eq('id', widget.appointmentId)
        .single();
    if (mounted) setState(() => _appointment = res);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _appointment?['status'] as String? ?? 'pending';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Booking Status', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Done'),
          ),
        ],
      ),
      body: _appointment == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  _buildStatusIndicator(status),
                  const SizedBox(height: 32),
                  _buildDetailsCard(),
                  const Spacer(),
                  if (status == 'cancelled') _buildRetryButton(),
                  if (status == 'confirmed' && _appointment?['meet_link'] != null)
                    _buildJoinButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusIndicator(String status) {
    switch (status) {
      case 'confirmed':
        return Column(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.green[50],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green[200]!, width: 3),
              ),
              child: Icon(Icons.check_circle, color: Colors.green[600], size: 64),
            ),
            const SizedBox(height: 20),
            Text('Booking Confirmed!',
                style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.green[800])),
            const SizedBox(height: 8),
            Text('Dr. ${widget.doctorName} has approved your appointment.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14)),
          ],
        );

      case 'cancelled':
        return Column(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red[200]!, width: 3),
              ),
              child: Icon(Icons.cancel, color: Colors.red[600], size: 64),
            ),
            const SizedBox(height: 20),
            Text('Appointment Declined',
                style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red[800])),
            const SizedBox(height: 8),
            Text('Unfortunately Dr. ${widget.doctorName} is unavailable for this slot.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.grey[600])),
          ],
        );

      default: // pending
        return Column(
          children: [
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.orange[200]!, width: 3),
                ),
                child: Icon(Icons.hourglass_top, color: Colors.orange[600], size: 64),
              ),
            ),
            const SizedBox(height: 20),
            Text('Waiting for Confirmation',
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Sent to Dr. ${widget.doctorName}. Awaiting approval...',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.grey[600])),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text('Live updates enabled',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.orange[700])),
              ],
            ),
          ],
        );
    }
  }

  Widget _buildDetailsCard() {
    final apptTime = _appointment?['appointment_time'] != null
        ? DateTime.tryParse(_appointment!['appointment_time'])
        : null;
    final timeLabel = apptTime != null
        ? DateFormat('EEEE, MMMM d • h:mm a').format(apptTime.toLocal())
        : 'TBD';
    final type = _appointment?['type'] as String? ?? 'online';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _buildDetailRow(Icons.person, 'Doctor', 'Dr. ${widget.doctorName}'),
          const Divider(height: 20),
          _buildDetailRow(Icons.access_time, 'Date & Time', timeLabel),
          const Divider(height: 20),
          _buildDetailRow(
            type == 'online' ? Icons.videocam : Icons.local_hospital,
            'Type',
            type == 'online' ? 'Online Consultation' : 'In-Person Visit',
          ),
          if (_appointment?['chief_complaint'] != null) ...[
            const Divider(height: 20),
            _buildDetailRow(Icons.medical_services, 'Complaint', _appointment!['chief_complaint']),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1B3C40)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500])),
              Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRetryButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          // Re-open booking flow
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookingFlowScreen(
                doctorId: _appointment?['doctor_id'] ?? '',
                doctorName: widget.doctorName,
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B3C40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text('Choose Another Slot',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildJoinButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () {
          // url_launcher would open meet_link
        },
        icon: const Icon(Icons.videocam, color: Colors.white),
        label: Text('Join Meeting',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[700],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
