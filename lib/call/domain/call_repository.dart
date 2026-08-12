import 'call_entity.dart';
import 'call_status.dart';

abstract class CallRepository {
  Future<CallEntity> startCall({
    required String callerId,
    required String calleeId,
    required bool isVideoCall,
    required String sdpOffer,
  });

  Future<void> answerCall({required String callId, required String sdpAnswer});

  Future<void> updateCallStatus({required String callId, required CallStatus status});

  Future<void> sendIceCandidate({required String callId, required Map<String, dynamic> candidate});

  Stream<CallEntity> listenToCall(String callId);

  Stream<CallEntity> listenToIncomingCalls(String userId);

  Stream<Map<String, dynamic>> listenToIceCandidates(String callId);
}