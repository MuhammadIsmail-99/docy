import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/api_service.dart';
import 'chat_bottom_sheet.dart';
import 'booking_flow_screen.dart';

class DoctorProfileScreen extends StatefulWidget {
  final String doctorId;

  const DoctorProfileScreen({super.key, required this.doctorId});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _api = ApiService();
  Map<String, dynamic>? _doctorData;
  Map<String, dynamic>? _earliestSlot;
  bool _isLoading = true;
  Timer? _chatTimer;

  @override
  void initState() {
    super.initState();
    _fetchDoctorData();
    // Show chat popup after 8 seconds of viewing profile
    _chatTimer = Timer(const Duration(seconds: 8), _showChatIfLoggedIn);
  }

  Future<void> _fetchDoctorData() async {
    try {
      final response = await _supabase
          .from('doctors')
          .select('*, profiles(full_name, email, phone)')
          .eq('id', widget.doctorId)
          .single();
      final slot = await _api.getEarliestSlot(widget.doctorId);
      if (mounted) {
        setState(() {
          _doctorData = response;
          _earliestSlot = slot;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showChatIfLoggedIn() {
    final user = _supabase.auth.currentUser;
    if (user == null || _doctorData == null || !mounted) return;
    final profile = _doctorData!['profiles'] as Map<String, dynamic>? ?? {};
    _showChat(profile['full_name'] as String? ?? 'Doctor');
  }

  void _showChat(String doctorName) {
    ChatBottomSheet.show(context, widget.doctorId, doctorName);
  }

  @override
  void dispose() {
    _chatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_doctorData == null) return const Scaffold(body: Center(child: Text('Doctor not found')));

    final profile = _doctorData!['profiles'] as Map<String, dynamic>? ?? {};
    final fullName = profile['full_name'] as String? ?? 'Doctor';
    final specialization = _doctorData!['specialization'] as String? ?? '';
    final city = _doctorData!['city'] as String? ?? '';
    final rating = (_doctorData!['rating'] as num?)?.toDouble() ?? 0.0;
    final fee = _doctorData!['consultation_fee'] as int? ?? 0;
    final bio = _doctorData!['bio'] as String? ?? 'No bio available.';
    final exp = _doctorData!['experience_years'] as int? ?? 0;
    final isAvailable = _doctorData!['is_available'] as bool? ?? false;
    final consultType = _doctorData!['consultation_type'] as String? ?? 'online';

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(fullName, specialization, isAvailable),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderInfo(city, rating, fee),
                  const SizedBox(height: 24),
                  _buildChips(consultType),
                  const SizedBox(height: 24),
                  _buildAboutSection(bio, exp),
                  const SizedBox(height: 24),
                  _buildAvailabilitySection(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomBar(fee, fullName),
    );
  }

  Widget _buildSliverAppBar(String name, String specialty, bool isAvailable) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: const Color(0xFF1B3C40),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: const Color(0xFF1B3C40),
              child: const Center(child: Icon(Icons.person, size: 100, color: Colors.white24)),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
            ),
            if (isAvailable)
              Positioned(
                top: 80,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(20)),
                  child: const Row(
                    children: [
                      Icon(Icons.circle, color: Colors.white, size: 8),
                      SizedBox(width: 4),
                      Text('Available Now', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            Text(specialty, style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo(String city, double rating, int fee) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _infoItem(Icons.location_on, city, 'Location'),
        _infoItem(Icons.star, rating.toStringAsFixed(1), 'Rating'),
        _infoItem(Icons.payments, 'Rs. $fee', 'Fee'),
      ],
    );
  }

  Widget _infoItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1B3C40).withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF1B3C40), size: 20),
        ),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: GoogleFonts.inter(color: Colors.grey, fontSize: 11)),
      ],
    );
  }

  Widget _buildChips(String consultType) {
    return Wrap(
      spacing: 8,
      children: [
        if (consultType == 'online' || consultType == 'both')
          _chip(Icons.videocam, 'Online', Colors.blue),
        if (consultType == 'physical' || consultType == 'both')
          _chip(Icons.local_hospital, 'In-Person', Colors.green),
      ],
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildAboutSection(String bio, int exp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About Doctor', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 12),
        Text(bio, style: GoogleFonts.inter(color: Colors.grey[700], height: 1.6)),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.workspace_premium, size: 16, color: Color(0xFF1B3C40)),
            const SizedBox(width: 8),
            Text('$exp+ Years of Experience',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF1B3C40))),
          ],
        ),
      ],
    );
  }

  Widget _buildAvailabilitySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[100]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Next Available Slot',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.green[900])),
                Text(
                  _earliestSlot?['label'] ?? 'No upcoming slots',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(int fee, String doctorName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showChat(doctorName),
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Chat with AI'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1B3C40)),
                foregroundColor: const Color(0xFF1B3C40),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookingFlowScreen(doctorId: widget.doctorId, doctorName: doctorName),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B3C40),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Book Now',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
