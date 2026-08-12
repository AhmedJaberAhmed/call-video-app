import '../domain/call_entity.dart';
import '../domain/call_status.dart';

class CallModel extends CallEntity {
  const CallModel({
    required super.id,
    required super.callerId,
    required super.calleeId,
    required super.status,
    super.sdpOffer,
    super.sdpAnswer,
    required super.createdAt,
    required super.isVideoCall,
  });

  factory CallModel.fromJson(Map<String, dynamic> json) {
    return CallModel(
      id: json['id'] as String,
      callerId: json['caller_id'] as String,
      calleeId: json['callee_id'] as String,
      status: CallStatus.values.byName(json['status'] as String),
      sdpOffer: json['sdp_offer'] as String?,
      sdpAnswer: json['sdp_answer'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isVideoCall: json['is_video_call'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'caller_id': callerId,
    'callee_id': calleeId,
    'status': status.name,
    'sdp_offer': sdpOffer,
    'sdp_answer': sdpAnswer,
    'created_at': createdAt.toIso8601String(),
    'is_video_call': isVideoCall,
  };
}