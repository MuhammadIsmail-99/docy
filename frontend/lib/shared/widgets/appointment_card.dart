import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'status_badge.dart';

class AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final String? doctorName;
  final String? patientName;
  final VoidCallback? onApprove;
  final VoidCallback? onDecline;
  final VoidCallback? onJoin;

  const AppointmentCard({
    super.key,
    required this.appointment,
    this.doctorName,
    this.patientName,
    this.onApprove,
    this.onDecline,
    this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final status = appointment['status'] as String? ?? 'pending';
    final apptTime = appointment['appointment_time'] != null
        ? DateTime.tryParse(appointment['appointment_time'])
        : null;
    final timeLabel = apptTime != null
        ? DateFormat('EEE MMM d, y • h:mm a').format(apptTime.toLocal())
        : 'Time TBD';
    final complaint = appointment['chief_complaint'] as String? ?? '';
    final type = appointment['type'] as String? ?? 'online';
    final meetLink = appointment['meet_link'] as String?;
    final displayName = doctorName ?? patientName ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFF1B3C40),
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(timeLabel, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              StatusBadge(status: status),
            ],
          ),
          if (complaint.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                complaint,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: type == 'online' ? Colors.blue[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  type == 'online' ? 'Online' : 'Physical',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: type == 'online' ? Colors.blue[700] : Colors.green[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (onDecline != null)
                TextButton(
                  onPressed: onDecline,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Decline'),
                ),
              if (onApprove != null) ...[
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B3C40),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Approve'),
                ),
              ],
              if (onJoin != null && meetLink != null) ...[
                ElevatedButton.icon(
                  onPressed: onJoin,
                  icon: const Icon(Icons.videocam, size: 16),
                  label: const Text('Join'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
