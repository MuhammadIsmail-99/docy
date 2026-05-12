import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class AdminApprovalScreen extends StatefulWidget {
  const AdminApprovalScreen({super.key});

  @override
  State<AdminApprovalScreen> createState() => _AdminApprovalScreenState();
}

class _AdminApprovalScreenState extends State<AdminApprovalScreen> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _pendingDoctors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingDoctors();
  }

  Future<void> _loadPendingDoctors() async {
    try {
      final doctors = await _adminService.getPendingDoctors();
      setState(() {
        _pendingDoctors = doctors;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleApproval(String doctorId, String status) async {
    try {
      await _adminService.updateVerificationStatus(doctorId, status);
      
      if (status == 'verified') {
        // Trigger re-embedding
        final updatedDoc = _pendingDoctors.firstWhere((d) => d['id'] == doctorId);
        await ApiService().embedDoctor({
          'doctor_id': doctorId,
          'specialization': updatedDoc['specialization'],
          'city': updatedDoc['city'],
          'bio': updatedDoc['bio'] ?? '',
          'experience_years': updatedDoc['experience_years'] ?? 0,
        });
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Doctor $status')),
      );
      _loadPendingDoctors();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text('Approval Queue', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: () => AuthService().signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingDoctors.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                      const SizedBox(height: 16),
                      Text('All caught up!', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('No pending doctor verifications.', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pendingDoctors.length,
                  itemBuilder: (context, index) {
                    final doc = _pendingDoctors[index];
                    final profile = doc['profiles'] as Map<String, dynamic>;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(child: Icon(Icons.person)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        profile['full_name'],
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      Text(
                                        doc['specialization'],
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Text('City: ${doc['city']}'),
                            Text('PMDC: ${doc['pmdc_number']}'),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => _handleApproval(doc['id'], 'rejected'),
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text('Reject'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => _handleApproval(doc['id'], 'verified'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1B3C40),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Approve'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
