import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SlotCard extends StatelessWidget {
  final Map<String, dynamic> slot;
  final bool isSelected;
  final VoidCallback onTap;

  const SlotCard({
    super.key,
    required this.slot,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final type = slot['type'] as String? ?? 'online';
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B3C40) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF1B3C40) : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFF1B3C40).withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              type == 'online' ? Icons.videocam : Icons.local_hospital,
              color: isSelected ? Colors.white : const Color(0xFF1B3C40),
              size: 20,
            ),
            const SizedBox(height: 8),
            Text(
              slot['label'] ?? '',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              type == 'online' ? 'Online Consult' : 'In-Person',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isSelected ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
