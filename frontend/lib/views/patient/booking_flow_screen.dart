import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/chat_service.dart';
import '../../shared/widgets/slot_card.dart';
import 'booking_status_screen.dart';

class BookingFlowScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final String? conversationId;

  const BookingFlowScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
    this.conversationId,
  });

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  final _api = ApiService();
  final _supabase = Supabase.instance.client;
  final _chatService = ChatService();
  final _pageCtrl = PageController();

  int _step = 0;
  bool _isLoading = true;
  bool _isBooking = false;

  List<dynamic> _slots = [];
  int _selectedSlot = 0;

  // Patient info
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _complaintCtrl = TextEditingController();
  int? _doctorFee;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Load slots
      final slots = await _api.getAvailableSlots(widget.doctorId, count: 3);

      // Load doctor fee
      final docRes = await _supabase.from('doctors').select('consultation_fee').eq('id', widget.doctorId).single();
      _doctorFee = docRes['consultation_fee'] as int?;

      // Pre-fill from triage if available
      if (widget.conversationId != null) {
        final conv = await _chatService.getConversation(widget.conversationId!);
        final triage = conv?['triage_data'] as Map<String, dynamic>?;
        if (triage != null) {
          _complaintCtrl.text = triage['chief_complaint']?.toString() ?? '';
          _contactCtrl.text = triage['contact']?.toString() ?? '';
        }
      }

      // Pre-fill patient name
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final profile = await _supabase.from('profiles').select('full_name').eq('id', user.id).single();
        _nameCtrl.text = profile['full_name']?.toString() ?? '';
      }

      setState(() {
        _slots = slots;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _nextStep() {
    if (_step < 3) {
      _step++;
      _pageCtrl.animateToPage(_step, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() {});
    }
  }

  void _prevStep() {
    if (_step > 0) {
      _step--;
      _pageCtrl.animateToPage(_step, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() {});
    }
  }

  Future<void> _confirmBooking() async {
    setState(() => _isBooking = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null || _slots.isEmpty) return;

      final slot = _slots[_selectedSlot];
      final slotType = slot['type'] as String? ?? 'online';

      final result = await _supabase
          .from('appointments')
          .insert({
            'patient_id': user.id,
            'doctor_id': widget.doctorId,
            'appointment_time': slot['datetime'],
            'duration_minutes': slot['duration_minutes'] ?? 30,
            'type': slotType,
            'status': 'pending',
            'chief_complaint': _complaintCtrl.text.trim(),
          })
          .select('id')
          .single();

      final appointmentId = result['id'] as String;

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BookingStatusScreen(
              appointmentId: appointmentId,
              doctorName: widget.doctorName,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Booking failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _step > 0 ? _prevStep : () => Navigator.pop(context),
        ),
        title: Text(
          ['Select Slot', 'Your Details', 'Confirm', 'Payment'][_step],
          style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / 4,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1B3C40)),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildSlotSelection(),
                _buildPatientInfo(),
                _buildConfirmation(),
                _buildMockPayment(),
              ],
            ),
    );
  }

  Widget _buildSlotSelection() {
    if (_slots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('No available slots', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Check back later or try another doctor.', style: GoogleFonts.inter(color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Book with Dr. ${widget.doctorName}',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Select your preferred time slot',
              style: GoogleFonts.inter(color: Colors.grey[600])),
          const SizedBox(height: 24),
          ..._slots.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SlotCard(
                  slot: e.value,
                  isSelected: _selectedSlot == e.key,
                  onTap: () => setState(() => _selectedSlot = e.key),
                ),
              )),
          const Spacer(),
          _buildNextButton('Continue', _nextStep),
        ],
      ),
    );
  }

  Widget _buildPatientInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Details', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('Review or update your information', style: GoogleFonts.inter(color: Colors.grey[600])),
          const SizedBox(height: 24),
          _buildField('Full Name', _nameCtrl, Icons.person_outline),
          const SizedBox(height: 16),
          _buildField('Phone Number', _contactCtrl, Icons.phone_outlined, type: TextInputType.phone),
          const SizedBox(height: 16),
          _buildField('Chief Complaint', _complaintCtrl, Icons.medical_services_outlined, maxLines: 3),
          const SizedBox(height: 32),
          _buildNextButton('Continue', _nextStep),
        ],
      ),
    );
  }

  Widget _buildConfirmation() {
    final slot = _slots.isNotEmpty ? _slots[_selectedSlot] : null;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Confirm Appointment', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildSummaryCard(slot),
          const Spacer(),
          _buildNextButton('Proceed to Payment', _nextStep),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic>? slot) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _buildSummaryRow(Icons.person, 'Doctor', 'Dr. ${widget.doctorName}'),
          const Divider(height: 20),
          _buildSummaryRow(Icons.access_time, 'Slot', slot?['label'] ?? 'TBD'),
          const Divider(height: 20),
          _buildSummaryRow(Icons.videocam, 'Type', (slot?['type'] ?? 'online').toString().toUpperCase()),
          if (_complaintCtrl.text.isNotEmpty) ...[
            const Divider(height: 20),
            _buildSummaryRow(Icons.medical_services, 'Complaint', _complaintCtrl.text),
          ],
          if (_doctorFee != null) ...[
            const Divider(height: 20),
            _buildSummaryRow(Icons.payments, 'Fee', 'PKR $_doctorFee'),
          ],
        ],
      ),
    );
  }

  Widget _buildMockPayment() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('Secure mock payment', style: GoogleFonts.inter(color: Colors.grey[600])),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B3C40), Color(0xFF2D5A5F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.credit_card, color: Colors.white70, size: 36),
                const SizedBox(height: 20),
                Text(
                  '**** **** **** 4242',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 20, letterSpacing: 2),
                ),
                const SizedBox(height: 8),
                Text('SMART DOCTOR CONNECT', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_doctorFee != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Consultation Fee', style: GoogleFonts.inter(color: Colors.grey[600])),
                  Text('PKR $_doctorFee',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isBooking ? null : _confirmBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B3C40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isBooking
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text('Confirm Booking',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B3C40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(label,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon,
      {TextInputType type = TextInputType.text, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[700])),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: type,
            maxLines: maxLines,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.grey[400]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1B3C40)),
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

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _complaintCtrl.dispose();
    super.dispose();
  }
}
