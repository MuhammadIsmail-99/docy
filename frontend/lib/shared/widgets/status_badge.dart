import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bg, icon) = switch (status) {
      'confirmed' => (Colors.green[700]!, Colors.green[50]!, Icons.check_circle),
      'cancelled' => (Colors.red[700]!, Colors.red[50]!, Icons.cancel),
      'completed' => (Colors.blue[700]!, Colors.blue[50]!, Icons.done_all),
      'pending' => (Colors.orange[700]!, Colors.orange[50]!, Icons.hourglass_empty),
      'verified' => (Colors.green[700]!, Colors.green[50]!, Icons.verified),
      'rejected' => (Colors.red[700]!, Colors.red[50]!, Icons.block),
      _ => (Colors.grey[700]!, Colors.grey[100]!, Icons.circle),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
