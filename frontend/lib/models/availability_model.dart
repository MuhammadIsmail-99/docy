class AvailabilityModel {
  final String? id;
  final String doctorId;
  final int dayOfWeek; // 0=Sunday
  final String startTime;
  final String endTime;
  final int slotDurationMinutes;

  AvailabilityModel({
    this.id,
    required this.doctorId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.slotDurationMinutes = 30,
  });

  factory AvailabilityModel.fromJson(Map<String, dynamic> json) {
    return AvailabilityModel(
      id: json['id'],
      doctorId: json['doctor_id'],
      dayOfWeek: json['day_of_week'],
      startTime: json['start_time'],
      endTime: json['end_time'],
      slotDurationMinutes: json['slot_duration_minutes'] ?? 30,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'doctor_id': doctorId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'slot_duration_minutes': slotDurationMinutes,
    };
  }
}
