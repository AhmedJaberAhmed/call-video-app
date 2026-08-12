import '../domain/call_entity.dart';
import '../domain/call_repository.dart';
import '../domain/call_status.dart';
import 'call_remote_datasource.dart';

class CallRepositoryImpl implements CallRepository {
  final CallRemoteDataSource remoteDataSource;

  CallRepositoryImpl(this.remoteDataSource);

  @override
  Future<CallEntity> startCall({
    required String callerId,
    required String calleeId,
    required bool isVideoCall,
    required String sdpOffer,
  }) async {
    final call = await remoteDataSource.createCall(
      callerId: callerId,
      calleeId: calleeId,
      isVideoCall: isVideoCall,
      sdpOffer: sdpOffer,
    );
    return call;
  }

  @override
  Future<void> answerCall({required String callId, required String sdpAnswer}) =>
      remoteDataSource.answerCall(callId: callId, sdpAnswer: sdpAnswer);

  @override
  Future<void> updateCallStatus({required String callId, required CallStatus status}) =>
      remoteDataSource.updateStatus(callId: callId, status: status);

  @override
  Future<void> sendIceCandidate({required String callId, required Map<String, dynamic> candidate}) =>
      remoteDataSource.sendIceCandidate(callId: callId, candidate: candidate);

  @override
  Stream<CallEntity> listenToCall(String callId) =>
      remoteDataSource.watchCall(callId);

  @override
  Stream<CallEntity> listenToIncomingCalls(String userId) =>
      remoteDataSource.watchIncomingCalls(userId);

  @override
  Stream<Map<String, dynamic>> listenToIceCandidates(String callId) =>
      remoteDataSource.watchIceCandidates(callId);
}