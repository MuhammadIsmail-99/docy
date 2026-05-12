import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../patient_home_screen.dart';
import '../doctor_home_screen.dart';

class RegisterScreen extends StatefulWidget {
  final int roleIndex; // 0 for Patient, 1 for Doctor
  const RegisterScreen({super.key, this.roleIndex = 0});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // Doctor specific
  final _specController = TextEditingController();
  final _cityController = TextEditingController();
  final _feeController = TextEditingController();
  final _pmdcController = TextEditingController();

  final _authService = AuthService();
  bool _isLoading = false;

  Future<void> _registerPatient() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signUpPatient(
        email: _emailController.text,
        password: _passwordController.text,
        fullName: _nameController.text,
        phone: _phoneController.text,
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PatientHomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerDoctor() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signUpDoctor(
        email: _emailController.text,
        password: _passwordController.text,
        fullName: _nameController.text,
        phone: _phoneController.text,
        specialization: _specController.text,
        city: _cityController.text,
        consultationType: 'both',
        experience: 5,
        fee: int.tryParse(_feeController.text) ?? 1000,
        bio: 'Professional doctor',
        pmdcNumber: _pmdcController.text,
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DoctorHomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDoctor = widget.roleIndex == 1;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          isDoctor ? 'Join as Doctor' : 'Create Account',
          style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: isDoctor ? _buildDoctorForm() : _buildPatientForm(),
    );
  }

  Widget _buildPatientForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Find a Doctor',
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1B3C40)),
          ),
          const SizedBox(height: 8),
          Text(
            'Join Docy to find the best care',
            style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          _buildTextField('Full Name', _nameController, Icons.person_outline),
          const SizedBox(height: 16),
          _buildTextField('Email', _emailController, Icons.email_outlined),
          const SizedBox(height: 16),
          _buildTextField('Phone Number', _phoneController, Icons.phone_outlined),
          const SizedBox(height: 16),
          _buildTextField('Password', _passwordController, Icons.lock_outline, isPassword: true),
          const SizedBox(height: 32),
          _buildSubmitButton('Join as Patient', _registerPatient),
        ],
      ),
    );
  }

  Widget _buildDoctorForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Professional Registration',
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1B3C40)),
          ),
          const SizedBox(height: 8),
          Text(
            'Join our network of healthcare providers',
            style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          _buildTextField('Full Name', _nameController, Icons.person_outline),
          const SizedBox(height: 16),
          _buildTextField('Email', _emailController, Icons.email_outlined),
          const SizedBox(height: 16),
          _buildTextField('Specialization', _specController, Icons.medical_services_outlined),
          const SizedBox(height: 16),
          _buildTextField('City', _cityController, Icons.location_city_outlined),
          const SizedBox(height: 16),
          _buildTextField('PMDC Number', _pmdcController, Icons.badge_outlined),
          const SizedBox(height: 16),
          _buildTextField('Consultation Fee (PKR)', _feeController, Icons.payments_outlined),
          const SizedBox(height: 16),
          _buildTextField('Password', _passwordController, Icons.lock_outline, isPassword: true),
          const SizedBox(height: 32),
          _buildSubmitButton('Join as Doctor', _registerDoctor),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700]),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
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

  Widget _buildSubmitButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B3C40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(label, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}
