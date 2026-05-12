class ConversationModel {
  final String id;
  final String patientId;
  final String doctorId;
  final bool aiActive;
  final bool intakeComplete;
  final Map<String, dynamic>? triageData;
  final DateTime createdAt;

  ConversationModel({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.aiActive,
    required this.intakeComplete,
    this.triageData,
    required this.createdAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'],
      patientId: json['patient_id'],
      doctorId: json['doctor_id'],
      aiActive: json['ai_active'] ?? true,
      intakeComplete: json['intake_complete'] ?? false,
      triageData: json['triage_data'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
