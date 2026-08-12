import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/call_status.dart';
import 'call_model.dart';


abstract class CallRemoteDataSource {
  Future<CallModel> createCall({
    required String callerId,
    required String calleeId,
    required bool isVideoCall,
    required String sdpOffer,
  });

  Future<void> answerCall({required String callId, required String sdpAnswer});

  Future<void> updateStatus({required String callId, required CallStatus status});

  Future<void> sendIceCandidate({required String callId, required Map<String, dynamic> candidate});

  Stream<CallModel> watchCall(String callId);

  Stream<CallModel> watchIncomingCalls(String userId);

  Stream<Map<String, dynamic>> watchIceCandidates(String callId);
}

class CallRemoteDataSourceImpl implements CallRemoteDataSource {
  final SupabaseClient client;
  CallRemoteDataSourceImpl(this.client);

  @override
  Future<CallModel> createCall({
    required String callerId,
    required String calleeId,
    required bool isVideoCall,
    required String sdpOffer,
  }) async {
    final response = await client
        .from('calls')
        .insert({
      'caller_id': callerId,
      'callee_id': calleeId,
      'status': CallStatus.ringing.name,
      'sdp_offer': sdpOffer,
      'is_video_call': isVideoCall,
    })
        .select()
        .single();
    return CallModel.fromJson(response);
  }

  @override
  Future<void> answerCall({required String callId, required String sdpAnswer}) async {
    await client.from('calls').update({
      'sdp_answer': sdpAnswer,
      'status': CallStatus.connecting.name,
    }).eq('id', callId);
  }

  @override
  Future<void> updateStatus({required String callId, required CallStatus status}) async {
    await client.from('calls').update({'status': status.name}).eq('id', callId);
  }

  @override
  Future<void> sendIceCandidate({required String callId, required Map<String, dynamic> candidate}) async {
    await client.from('ice_candidates').insert({
      'call_id': callId,
      'candidate': candidate,
    });
  }

  @override
  Stream<CallModel> watchCall(String callId) {
    return client
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('id', callId)
        .map((rows) => CallModel.fromJson(rows.first));
  }

  @override
  Stream<CallModel> watchIncomingCalls(String userId) {
    return client
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('callee_id', userId)
        .map((rows) => rows.map(CallModel.fromJson).toList())
        .expand((calls) => calls)
        .where((call) => call.status == CallStatus.ringing);
  }

  @override
  Stream<Map<String, dynamic>> watchIceCandidates(String callId) {
    return client
        .from('ice_candidates')
        .stream(primaryKey: ['id'])
        .eq('call_id', callId)
        .map((rows) => rows.map((r) => r['candidate'] as Map<String, dynamic>))
        .expand((c) => c);
  }
}