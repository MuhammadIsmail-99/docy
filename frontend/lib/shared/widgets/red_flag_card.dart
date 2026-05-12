import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RedFlagCard extends StatelessWidget {
  const RedFlagCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emergency, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text(
            '⚠️ Emergency Situation',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.red[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your symptoms need immediate attention.\nPlease go to the nearest emergency room\nor call 1122 right now.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.red[700], height: 1.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.phone, size: 18),
              label: const Text('Call 1122'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
