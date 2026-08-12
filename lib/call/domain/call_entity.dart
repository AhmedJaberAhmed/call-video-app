import 'call_status.dart';

class CallEntity {
  final String id;
  final String callerId;
  final String calleeId;
  final CallStatus status;
  final String? sdpOffer;
  final String? sdpAnswer;
  final DateTime createdAt;
  final bool isVideoCall;

  const CallEntity({
    required this.id,
    required this.callerId,
    required this.calleeId,
    required this.status,
    this.sdpOffer,
    this.sdpAnswer,
    required this.createdAt,
    required this.isVideoCall,
  });
}