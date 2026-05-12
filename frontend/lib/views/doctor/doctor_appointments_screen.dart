import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/appointment_card.dart';

class DoctorAppointmentsScreen extends StatefulWidget {
  const DoctorAppointmentsScreen({super.key});

  @override
  State<DoctorAppointmentsScreen> createState() => _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _api = ApiService();
  late TabController _tabCtrl;
  StreamSubscription? _sub;

  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _confirmed = [];
  List<Map<String, dynamic>> _past = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _setupStream();
  }

  void _setupStream() {
    final user = AuthService().currentUser;
    if (user == null) return;

    _sub = _supabase
        .from('appointments')
        .stream(primaryKey: ['id'])
        .eq('doctor_id', user.id)
        .order('appointment_time', ascending: true)
        .listen((rows) async {
      if (!mounted) return;

      // Enrich with patient names
      final enriched = <Map<String, dynamic>>[];
      for (final row in rows) {
        try {
          final pat = await _supabase
              .from('profiles')
              .select('full_name')
              .eq('id', row['patient_id'])
              .single();
          enriched.add({...row, '_patient_name': pat['full_name']});
        } catch (_) {
          enriched.add({...row, '_patient_name': 'Unknown Patient'});
        }
      }

      final now = DateTime.now();
      setState(() {
        _pending = enriched.where((a) => a['status'] == 'pending').toList();
        _confirmed = enriched
            .where((a) => a['status'] == 'confirmed' && DateTime.tryParse(a['appointment_time'] ?? '')?.isAfter(now) == true)
            .toList();
        _past = enriched
            .where((a) => a['status'] == 'completed' || a['status'] == 'cancelled' ||
                (a['status'] == 'confirmed' && DateTime.tryParse(a['appointment_time'] ?? '')?.isBefore(now) == true))
            .toList();
        _isLoading = false;
      });
    });
  }

  Future<void> _approveAppointment(Map<String, dynamic> appt) async {
    final mockLink = 'https://meet.google.com/mock-${appt['id'].toString().substring(0, 8)}';
    await _supabase.from('appointments').update({
      'status': 'confirmed',
      'meet_link': mockLink,
    }).eq('id', appt['id']);

    // Trigger confirmation email
    await _api.sendConfirmationEmail(appt['id']);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment confirmed! Patient notified.')),
      );
    }
  }

  Future<void> _declineAppointment(String appointmentId) async {
    await _supabase.from('appointments').update({'status': 'cancelled'}).eq('id', appointmentId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment declined.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text('Appointments', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFF1B3C40),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF1B3C40),
          tabs: [
            Tab(text: 'Pending${_pending.isNotEmpty ? " (${_pending.length})" : ""}'),
            const Tab(text: 'Upcoming'),
            const Tab(text: 'Past'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildList(_pending, isPending: true),
                _buildList(_confirmed),
                _buildList(_past),
              ],
            ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, {bool isPending = false}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No appointments here', style: GoogleFonts.inter(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final appt = items[i];
        return AppointmentCard(
          appointment: appt,
          patientName: appt['_patient_name'] as String?,
          onApprove: isPending ? () => _approveAppointment(appt) : null,
          onDecline: isPending ? () => _declineAppointment(appt['id']) : null,
        );
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }
}
