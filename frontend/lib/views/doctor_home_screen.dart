import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/doctor_service.dart';
import '../models/doctor_model.dart';
import 'doctor/profile_screen.dart';
import 'doctor/availability_screen.dart';
import 'doctor/doctor_appointments_screen.dart';

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  final DoctorService _doctorService = DoctorService();
  DoctorModel? _doctor;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDoctorData();
  }

  Future<void> _loadDoctorData() async {
    try {
      final user = AuthService().currentUser;
      if (user != null) {
        final doctor = await _doctorService.getDoctorProfile(user.id);
        setState(() {
          _doctor = doctor;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_doctor == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Error loading doctor profile'),
              TextButton(onPressed: _loadDoctorData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final bool isVerified = _doctor!.verificationStatus == 'verified';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text('Docy for Doctors', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: () async {
              await AuthService().signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusHeader(isVerified),
            const SizedBox(height: 32),
            Text('Your Dashboard', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildDashboardCard('Profile', Icons.person_outline, const Color(0xFFE0F2FE),
                    const Color(0xFF0284C7),
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => DoctorProfileScreen()))),
                _buildDashboardCard('Availability', Icons.calendar_today_outlined, const Color(0xFFF0FDF4),
                    const Color(0xFF16A34A),
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => DoctorAvailabilityScreen()))),
                _buildDashboardCard('Appointments', Icons.assignment_outlined, const Color(0xFFFFF7ED),
                    const Color(0xFFEA580C),
                    isVerified
                        ? () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const DoctorAppointmentsScreen()))
                        : null),
                _buildDashboardCard('Reviews', Icons.star_outline, const Color(0xFFFAF5FF),
                    const Color(0xFF9333EA), isVerified ? () {} : null),
              ],
            ),
            if (isVerified) ...[
              const SizedBox(height: 32),
              _buildAvailabilityToggle(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(bool isVerified) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isVerified ? const Color(0xFF1B3C40) : Colors.amber[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isVerified ? Colors.transparent : Colors.amber[200]!),
      ),
      child: Row(
        children: [
          Icon(isVerified ? Icons.verified : Icons.hourglass_empty,
              color: isVerified ? Colors.white : Colors.amber[700], size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVerified ? 'Verified Account' : 'Profile Under Review',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: isVerified ? Colors.white : Colors.amber[900]),
                ),
                Text(
                  isVerified
                      ? 'Your profile is active and visible to patients.'
                      : 'We are reviewing your credentials. Usually 24-48 hours.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: isVerified ? Colors.white70 : Colors.amber[800]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(
      String title, IconData icon, Color bgColor, Color iconColor, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1.0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(height: 12),
              Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Available for Instant Booking', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                Text('Patients see you as "Available Now"',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Switch.adaptive(
            value: _doctor!.isAvailable,
            activeColor: const Color(0xFF1B3C40),
            onChanged: (value) async {
              setState(() => _doctor = _doctor!.copyWith(isAvailable: value));
              await _doctorService.toggleAvailability(_doctor!.id, value);
            },
          ),
        ],
      ),
    );
  }
}
