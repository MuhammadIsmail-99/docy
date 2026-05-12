class TriageBriefModel {
  final String id;
  final String conversationId;
  final String doctorId;
  final String? patientName;
  final String? patientContact;
  final String? chiefComplaint;
  final String? duration;
  final String? severity;
  final bool redFlags;
  final String? soapNote;
  final String status; // 'new' | 'reviewed' | 'dismissed'
  final DateTime createdAt;

  TriageBriefModel({
    required this.id,
    required this.conversationId,
    required this.doctorId,
    this.patientName,
    this.patientContact,
    this.chiefComplaint,
    this.duration,
    this.severity,
    required this.redFlags,
    this.soapNote,
    required this.status,
    required this.createdAt,
  });

  factory TriageBriefModel.fromJson(Map<String, dynamic> json) {
    return TriageBriefModel(
      id: json['id'],
      conversationId: json['conversation_id'],
      doctorId: json['doctor_id'],
      patientName: json['patient_name'],
      patientContact: json['patient_contact'],
      chiefComplaint: json['chief_complaint'],
      duration: json['duration'],
      severity: json['severity'],
      redFlags: json['red_flags'] ?? false,
      soapNote: json['soap_note'],
      status: json['status'] ?? 'new',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
