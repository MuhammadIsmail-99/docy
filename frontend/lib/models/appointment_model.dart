class AppointmentModel {
  final String id;
  final String patientId;
  final String doctorId;
  final DateTime appointmentTime;
  final int durationMinutes;
  final String type;
  final String status;
  final String? chiefComplaint;
  final String? notes;
  final String? meetLink;
  final DateTime createdAt;

  AppointmentModel({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.appointmentTime,
    required this.durationMinutes,
    required this.type,
    required this.status,
    this.chiefComplaint,
    this.notes,
    this.meetLink,
    required this.createdAt,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'],
      patientId: json['patient_id'],
      doctorId: json['doctor_id'],
      appointmentTime: DateTime.parse(json['appointment_time']),
      durationMinutes: json['duration_minutes'] ?? 30,
      type: json['type'] ?? 'online',
      status: json['status'] ?? 'pending',
      chiefComplaint: json['chief_complaint'],
      notes: json['notes'],
      meetLink: json['meet_link'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patient_id': patientId,
        'doctor_id': doctorId,
        'appointment_time': appointmentTime.toIso8601String(),
        'duration_minutes': durationMinutes,
        'type': type,
        'status': status,
        if (chiefComplaint != null) 'chief_complaint': chiefComplaint,
        if (notes != null) 'notes': notes,
        if (meetLink != null) 'meet_link': meetLink,
      };
}
