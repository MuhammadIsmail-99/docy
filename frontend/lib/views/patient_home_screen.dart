import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../components/doctor_card.dart';
import 'patient/search_results_screen.dart';
import 'patient/booking_status_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  bool _isAvailableOnly = false;

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _pages.addAll([
      PatientHomeView(
        searchController: _searchController,
        isAvailableOnly: _isAvailableOnly,
        onToggleAvailable: () => setState(() => _isAvailableOnly = !_isAvailableOnly),
        onSearch: (query) => _handleSearch(context, query),
      ),
      const Center(child: Text('Appointments Page')),
      const Center(child: Text('Profile Page')),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: _currentIndex == 0 ? AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Docy',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
      ) : null,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          PatientHomeView(
            searchController: _searchController,
            isAvailableOnly: _isAvailableOnly,
            onToggleAvailable: () => setState(() => _isAvailableOnly = !_isAvailableOnly),
            onSearch: (query) => _handleSearch(context, query),
          ),
          const PatientAppointmentsView(),
          const PatientProfileView(),
        ],
      ),
      extendBody: true, // Allows body to go behind bottom nav for the pill effect
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1B3C40),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1B3C40).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildNavItem(0, Icons.home_rounded, 'Home'),
                  const SizedBox(width: 12),
                  _buildNavItem(1, Icons.calendar_month_rounded, 'Appointments'),
                  const SizedBox(width: 12),
                  _buildNavItem(2, Icons.person_rounded, 'Profile'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected ? const Color(0xFF1B3C40) : Colors.white.withOpacity(0.7),
          size: 24,
        ),
      ),
    );
  }

  void _handleSearch(BuildContext context, String query) {
    if (query.trim().isEmpty) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(
          query: query,
          availableOnly: _isAvailableOnly,
        ),
      ),
    );
  }
}

class PatientHomeView extends StatelessWidget {
  final TextEditingController searchController;
  final bool isAvailableOnly;
  final VoidCallback onToggleAvailable;
  final Function(String) onSearch;

  const PatientHomeView({
    super.key,
    required this.searchController,
    required this.isAvailableOnly,
    required this.onToggleAvailable,
    required this.onSearch,
  });

  static const _specialties = [
    ('Heart', Icons.favorite, '❤️'),
    ('Skin', Icons.face, '🧴'),
    ('Bones', Icons.accessibility_new, '🦴'),
    ('Brain', Icons.psychology, '🧠'),
    ('Child', Icons.child_care, '👶'),
    ('Women', Icons.female, '👩‍⚕️'),
    ('General', Icons.local_hospital, '🏥'),
    ('Mental', Icons.self_improvement, '🧘'),
  ];

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final firstName = (user?.userMetadata?['full_name'] as String?)?.split(' ').first ?? 'there';

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text('Hello, $firstName 👋',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text('Find your doctor',
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 16),
            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: TextField(
                controller: searchController,
                onSubmitted: onSearch,
                decoration: InputDecoration(
                  hintText: "Search by symptom or specialty...",
                  hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isAvailableOnly ? Icons.event_available : Icons.event_note,
                      color: isAvailableOnly ? const Color(0xFF1B3C40) : Colors.grey,
                    ),
                    onPressed: onToggleAvailable,
                    tooltip: 'Available only',
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
            const SizedBox(height: 28),
            // Stats row
            Row(
              children: [
                _statCard('500+', 'Doctors'),
                const SizedBox(width: 12),
                _statCard('4.8★', 'Avg Rating'),
                const SizedBox(width: 12),
                _statCard('24/7', 'AI Support'),
              ],
            ),
            const SizedBox(height: 28),
            Text('Browse by Specialty',
                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: _specialties.map((s) => _specialtyChip(context, s.$1, s.$2, s.$3)).toList(),
            ),
            const SizedBox(height: 28),
            // How it works
            Text('How it works',
                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 16),
            _stepCard('1', 'Describe your symptoms', 'Tell our AI what you\'re experiencing'),
            _stepCard('2', 'Get matched', 'AI suggests the right specialist for you'),
            _stepCard('3', 'Book & consult', 'Pick a slot and meet your doctor online or in-person'),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF1B3C40))),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _specialtyChip(BuildContext context, String label, IconData icon, String emoji) {
    return GestureDetector(
      onTap: () => onSearch(label),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _stepCard(String step, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: const BoxDecoration(color: Color(0xFF1B3C40), shape: BoxShape.circle),
            child: Center(child: Text(step, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PatientAppointmentsView extends StatefulWidget {
  const PatientAppointmentsView({super.key});

  @override
  State<PatientAppointmentsView> createState() => _PatientAppointmentsViewState();
}

class _PatientAppointmentsViewState extends State<PatientAppointmentsView> {
  final _supabase = Supabase.instance.client;
  StreamSubscription? _sub;
  List<Map<String, dynamic>> _upcoming = [];
  List<Map<String, dynamic>> _past = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupStream();
  }

  void _setupStream() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    _sub = _supabase
        .from('appointments')
        .stream(primaryKey: ['id'])
        .eq('patient_id', user.id)
        .order('appointment_time', ascending: true)
        .listen((rows) async {
      if (!mounted) return;
      final enriched = <Map<String, dynamic>>[];
      for (final row in rows) {
        try {
          final doc = await _supabase
              .from('doctors')
              .select('specialization, profiles(full_name)')
              .eq('id', row['doctor_id'])
              .single();
          enriched.add({
            ...row,
            '_doctor_name': (doc['profiles'] as Map?)?['full_name'] ?? 'Doctor',
            '_specialization': doc['specialization'] ?? '',
          });
        } catch (_) {
          enriched.add({...row, '_doctor_name': 'Doctor', '_specialization': ''});
        }
      }
      final now = DateTime.now();
      if (!mounted) return;
      setState(() {
        _upcoming = enriched.where((a) {
          final t = DateTime.tryParse(a['appointment_time'] ?? '');
          final s = a['status'] as String? ?? '';
          return (s == 'pending' || s == 'confirmed') && (t == null || t.isAfter(now));
        }).toList();
        _past = enriched.where((a) {
          final t = DateTime.tryParse(a['appointment_time'] ?? '');
          final s = a['status'] as String? ?? '';
          return s == 'completed' || s == 'cancelled' ||
              (s == 'confirmed' && t != null && t.isBefore(now));
        }).toList();
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _formatTime(String? ts) {
    if (ts == null) return 'TBD';
    final t = DateTime.tryParse(ts);
    if (t == null) return ts;
    final local = t.toLocal();
    return '${local.day}/${local.month}, ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Appointments', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          if (_upcoming.isEmpty) _buildNoUpcoming() else _buildUpcomingCard(_upcoming.first),
          if (_upcoming.length > 1) ...[
            const SizedBox(height: 16),
            Text('More Upcoming', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._upcoming.skip(1).map((a) => _buildHistoryRow(a)),
          ],
          if (_past.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Recent History', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ..._past.map((a) => _buildHistoryRow(a)),
          ],
        ],
      ),
    );
  }

  Widget _buildNoUpcoming() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_busy, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text('No upcoming appointments', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildUpcomingCard(Map<String, dynamic> appt) {
    final isConfirmed = appt['status'] == 'confirmed';
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => BookingStatusScreen(appointmentId: appt['id']),
      )),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1B3C40),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: const Color(0xFF1B3C40).withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Icon(isConfirmed ? Icons.check_circle : Icons.access_time, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(isConfirmed ? 'Confirmed' : 'Pending Approval',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Colors.white70),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const CircleAvatar(radius: 24, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white)),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(appt['_doctor_name'], style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${appt['_specialization']} • ${appt['consultation_type'] ?? 'Online'}',
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.videocam, color: Colors.white70),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_month, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text(_formatTime(appt['appointment_time']),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryRow(Map<String, dynamic> appt) {
    final status = appt['status'] as String? ?? '';
    final color = status == 'completed' ? Colors.green : (status == 'cancelled' ? Colors.red : Colors.orange);
    final label = status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : status;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => BookingStatusScreen(appointmentId: appt['id']),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF1B3C40).withOpacity(0.1),
              child: const Icon(Icons.person, color: Color(0xFF1B3C40)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appt['_doctor_name'], style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  Text('${appt['_specialization']} • ${_formatTime(appt['appointment_time'])}',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(label, style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class PatientProfileView extends StatelessWidget {
  const PatientProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final fullName = user?.userMetadata?['full_name'] ?? 'Guest User';
    final email = user?.email ?? 'No email available';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      child: Column(
        children: [
          // Profile Header
          const CircleAvatar(
            radius: 50,
            backgroundColor: Color(0xFF1B3C40),
            child: Icon(Icons.person, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            fullName,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Text(
            email,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 30),
          
          // Basic Info Cards
          Row(
            children: [
              _buildInfoCard('Blood', 'O+', Icons.water_drop, Colors.red),
              const SizedBox(width: 15),
              _buildInfoCard('Weight', '72kg', Icons.monitor_weight, Colors.blue),
              const SizedBox(width: 15),
              _buildInfoCard('Height', '5.9ft', Icons.height, Colors.green),
            ],
          ),
          const SizedBox(height: 30),
          
          // Menu Items
          _buildMenuItem(Icons.person_outline, 'Personal Information', () {}),
          _buildMenuItem(Icons.history, 'Medical History', () {}),
          _buildMenuItem(Icons.payment, 'Payment Methods', () {}),
          _buildMenuItem(Icons.settings_outlined, 'Settings', () {}),
          _buildMenuItem(Icons.help_outline, 'Help & Support', () {}),
          const Divider(height: 40),
          _buildMenuItem(Icons.logout, 'Logout', () async {
            await AuthService().signOut();
            if (context.mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            }
          }, color: Colors.red),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap, {Color color = Colors.black87}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
    );
  }
}
