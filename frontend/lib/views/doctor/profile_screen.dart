import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/doctor_service.dart';
import '../../services/api_service.dart';
import '../../models/doctor_model.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final DoctorService _doctorService = DoctorService();
  final _formKey = GlobalKey<FormState>();
  
  DoctorModel? _doctor;
  bool _isLoading = true;
  bool _isSaving = false;

  late TextEditingController _bioController;
  late TextEditingController _feeController;
  String _consultationType = 'online';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = AuthService().currentUser;
    if (user != null) {
      final doctor = await _doctorService.getDoctorProfile(user.id);
      if (doctor != null) {
        setState(() {
          _doctor = doctor;
          _bioController = TextEditingController(text: doctor.bio);
          _feeController = TextEditingController(text: doctor.consultationFee.toString());
          _consultationType = doctor.consultationType;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        await _doctorService.updateDoctorProfile(_doctor!.id, {
          'bio': _bioController.text,
          'consultation_fee': int.parse(_feeController.text),
          'consultation_type': _consultationType,
        });
        
        // Trigger re-embedding in backend (t18)
        await ApiService().embedDoctor({
          'doctor_id': _doctor!.id,
          'specialization': _doctor!.specialization,
          'city': _doctor!.city,
          'bio': _bioController.text,
          'experience_years': _doctor!.experienceYears,
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Edit Profile', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: [
          if (_isSaving)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ))
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReadOnlyInfo(),
              const SizedBox(height: 32),
              _buildEditableFields(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Color(0xFF1B3C40),
                child: Icon(Icons.person, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _doctor!.specialization,
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      _doctor!.city,
                      style: GoogleFonts.inter(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _doctor!.verificationStatus.toUpperCase(),
                  style: TextStyle(color: Colors.blue[700], fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          _buildInfoRow('PMDC Number', _doctor!.pmdcNumber),
          _buildInfoRow('Experience', '${_doctor!.experienceYears} Years'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: Colors.grey[600])),
          Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildEditableFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Professional Bio', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _bioController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Describe your expertise and approach...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (v) => v!.isEmpty ? 'Please enter a bio' : null,
        ),
        const SizedBox(height: 24),
        Text('Consultation Fee (PKR)', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _feeController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'e.g. 2000',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixText: 'Rs. ',
          ),
          validator: (v) => v!.isEmpty ? 'Please enter a fee' : null,
        ),
        const SizedBox(height: 24),
        Text('Consultation Type', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _consultationType,
          items: const [
            DropdownMenuItem(value: 'online', child: Text('Online Only')),
            DropdownMenuItem(value: 'physical', child: Text('Physical Only')),
            DropdownMenuItem(value: 'both', child: Text('Both Online & Physical')),
          ],
          onChanged: (v) => setState(() => _consultationType = v!),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
