import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'views/patient_home_screen.dart';
import 'views/doctor_home_screen.dart';
import 'views/welcome_screen.dart';
import 'views/auth/login_screen.dart';
import 'views/admin/approval_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://ncrofbxunskjtaxlobiv.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5jcm9mYnh1bnNranRheGxvYml2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg1NTU5MzMsImV4cCI6MjA5NDEzMTkzM30.5O2if8mPPYrUSMMG3d2PneE4h6shjnULl0vrmVTghZ8',
  );
  
  runApp(const DocyApp());
}

class DocyApp extends StatelessWidget {
  const DocyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Docy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF8F9FB),
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          return FutureBuilder<String?>(
            future: _getUserRole(session.user.id),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (roleSnapshot.data == 'doctor') {
                return const DoctorHomeScreen();
              }
              if (roleSnapshot.data == 'admin') {
                return const AdminApprovalScreen();
              }
              return const PatientHomeScreen();
            },
          );
        }
        return const WelcomeScreen();
      },
    );
  }

  Future<String?> _getUserRole(String userId) async {
    final response = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .single();
    return response['role'] as String?;
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF60A5FA), Color(0xFF6366F1), Color(0xFFA855F7)],
              ).createShader(bounds),
              child: Text(
                'Smart Doctor\nConnect AI',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'The future of healthcare in Pakistan. Instant connections, AI-driven suggestions, and seamless scheduling.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                color: Colors.grey[400],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),
            _buildButton(
              'Find a Doctor',
              Colors.blue[600]!,
              true,
            ),
            const SizedBox(height: 16),
            _buildButton(
              'For Doctors',
              Colors.white.withOpacity(0.1),
              false,
            ),
            const SizedBox(height: 64),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFeatureIcon('AI Search', Icons.search),
                _buildFeatureIcon('Smart Chat', Icons.chat_bubble_outline),
                _buildFeatureIcon('Booking', Icons.calendar_today),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String text, Color color, bool hasShadow) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(28),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
        border: !hasShadow ? Border.all(color: Colors.white24) : null,
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureIcon(String label, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Icon(icon, color: Colors.blue[400], size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
      ],
    );
  }
}
