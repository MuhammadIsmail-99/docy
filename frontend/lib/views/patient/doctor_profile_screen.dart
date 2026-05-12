import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/api_service.dart';

class DoctorProfileScreen extends StatefulWidget {
  final String doctorId;

  const DoctorProfileScreen({super.key, required this.doctorId});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _apiService = ApiService();
  Map<String, dynamic>? _doctorData;
  Map<String, dynamic>? _earliestSlot;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDoctorData();
  }

  Future<void> _fetchDoctorData() async {
    try {
      final response = await _supabase
          .from('doctors')
          .select('*, profiles(full_name, email, phone)')
          .eq('id', widget.doctorId)
          .single();
      
      final slotResponse = await _apiService.getEarliestSlot(widget.doctorId);

      if (mounted) {
        setState(() {
          _doctorData = response;
          _earliestSlot = slotResponse;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_doctorData == null) {
      return const Scaffold(
        body: Center(child: Text('Doctor not found')),
      );
    }

    final profile = _doctorData!['profiles'];
    final fullName = profile['full_name'];
    final specialization = _doctorData!['specialization'];
    final city = _doctorData!['city'];
    final rating = _doctorData!['rating']?.toDouble() ?? 0.0;
    final fee = _doctorData!['consultation_fee'];
    final bio = _doctorData!['bio'] ?? 'No bio available';
    final exp = _doctorData!['experience_years'];

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(fullName, specialization),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderInfo(city, rating, fee),
                  const SizedBox(height: 30),
                  _buildAboutSection(bio, exp),
                  const SizedBox(height: 30),
                  _buildAvailabilitySection(),
                  const SizedBox(height: 100), // Space for sticky button
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _buildBookingBar(fee),
    );
  }

  Widget _buildSliverAppBar(String name, String specialty) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: const Color(0xFF1B3C40),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: const Color(0xFF1B3C40),
              child: const Center(
                child: Icon(Icons.person, size: 100, color: Colors.white24),
              ),
            ),
            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
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
            Text(
              name,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            Text(
              specialty,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo(String city, double rating, int fee) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildInfoItem(Icons.location_on, 'Location', city),
        _buildInfoItem(Icons.star, 'Rating', rating.toString()),
        _buildInfoItem(Icons.payments, 'Fee', 'Rs. $fee'),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
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
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildAboutSection(String bio, int exp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About Doctor',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 12),
        Text(
          bio,
          style: GoogleFonts.inter(color: Colors.grey[700], height: 1.5),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.history, size: 16, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              '$exp+ Years of Experience',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.blue[800]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvailabilitySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_available, color: Colors.green),
              const SizedBox(width: 10),
              Text(
                'Next Available Slot',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _earliestSlot?['label'] ?? 'No slots available soon',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Book now to secure this time',
            style: GoogleFonts.inter(color: Colors.green[700], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingBar(int fee) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Consultation Fee',
                style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
              ),
              Text(
                'Rs. $fee',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: const Color(0xFF1B3C40),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                // Navigate to real booking screen or show bottom sheet for date selection
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B3C40),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                'Book Appointment',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
