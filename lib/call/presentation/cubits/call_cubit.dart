import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/webrtc_service.dart';
import '../../domain/call_entity.dart';
import '../../domain/call_repository.dart';
import '../../domain/call_status.dart';
import 'call_state.dart';

class CallCubit extends Cubit<CallState> {
  final CallRepository _callRepository;
  final WebRTCService _webRTCService;
  final SupabaseClient _supabase;

  Timer? _callTimer;
  String? _currentCallId;
  String? _currentUserId;
  StreamSubscription? _callSubscription;
  StreamSubscription? _incomingCallSubscription;
  StreamSubscription? _iceSubscription;

  CallCubit({
    required CallRepository callRepository,
    required WebRTCService webRTCService,
    required SupabaseClient supabase,
  })  : _callRepository = callRepository,
        _webRTCService = webRTCService,
        _supabase = supabase,
        super(CallInitial()) {
    // Previously nothing told the database when the peer connection
    // actually reached "connected" — the caller's UI relied on a DB status
    // change that never happened. WebRTCService now fires this callback
    // when RTCPeerConnectionState hits connected; we push that to the DB
    // here so both sides' listenToCall() streams pick it up.
    _webRTCService.onConnected = _handleWebRtcConnected;
  }

  WebRTCService get webRTCService => _webRTCService;

  void _handleWebRtcConnected() {
    print('[CallCubit] _handleWebRtcConnected() _currentCallId=$_currentCallId');
    if (_currentCallId == null) return;
    _callRepository.updateCallStatus(
      callId: _currentCallId!,
      status: CallStatus.connected,
    ).then((_) {
      print('[CallCubit] updateCallStatus(connected) complete for $_currentCallId');
    }).catchError((e, st) {
      print('[CallCubit] updateCallStatus(connected) ERROR: $e');
      print(st);
    });
  }

  void initialize(String userId) {
    print('[CallCubit] initialize() called with userId=$userId');
    _currentUserId = userId;
    _webRTCService.initialize(userId);
    _listenForIncomingCalls();
    print('[CallCubit] initialize() complete');
  }

  void _listenForIncomingCalls() {
    print('[CallCubit] _listenForIncomingCalls() called, _currentUserId=$_currentUserId');
    if (_currentUserId == null) {
      print('[CallCubit] _listenForIncomingCalls() aborted: _currentUserId is null');
      return;
    }

    _incomingCallSubscription?.cancel();
    print('[CallCubit] subscribing to listenToIncomingCalls stream');
    _incomingCallSubscription = _callRepository
        .listenToIncomingCalls(_currentUserId!)
        .listen((call) {
      print('[CallCubit] incoming call event: id=${call.id}, status=${call.status}, callerId=${call.callerId}');

      if (call.status == CallStatus.ringing && _currentCallId == null) {
        print('[CallCubit] call is ringing and no active call, fetching caller name for ${call.callerId}');
        _getCallerName(call.callerId).then((callerName) {
          print('[CallCubit] caller name resolved: $callerName');
          if (_currentCallId == null) {
            print('[CallCubit] emitting IncomingCallState for callId=${call.id}');
            emit(IncomingCallState(
              callId: call.id,
              callerId: call.callerId,
              calleeId: call.calleeId,
              isVideo: call.isVideoCall,
              callerName: callerName ?? 'Unknown',
            ));
          } else {
            print('[CallCubit] skipped emitting IncomingCallState, call already handled (_currentCallId=$_currentCallId)');
          }
        });
      } else {
        print('[CallCubit] ignored incoming call event (status=${call.status}, _currentCallId=$_currentCallId)');
      }
    }, onError: (e, st) {
      print('[CallCubit] listenToIncomingCalls stream ERROR: $e');
      print(st);
    });
    print('[CallCubit] _listenForIncomingCalls() subscription set up');
  }

  Future<String?> _getCallerName(String userId) async {
    print('[CallCubit] _getCallerName() called for userId=$userId');
    try {
      final response = await _supabase
          .from('users')
          .select('name')
          .eq('id', userId)
          .single();
      print('[CallCubit] _getCallerName() response=$response');
      return response['name'] as String?;
    } catch (e) {
      print('[CallCubit] _getCallerName() ERROR: $e');
      return null;
    }
  }

  Future<void> initiateCall({
    required String callerId,
    required String calleeId,
    required bool isVideo,
    required String calleeName,
  }) async {
    print('[CallCubit] initiateCall() START callerId=$callerId calleeId=$calleeId isVideo=$isVideo');
    // Tracks whether initializeCall() succeeded so we know whether to
    // release the mic/camera if a later step (offer creation, DB insert)
    // throws. Previously a failure after this point left the stream open.
    var webRtcInitialized = false;
    try {
      emit(CallConnectingState());
      print('[CallCubit] emitted CallConnectingState');

      final hasPermissions = await _webRTCService.requestPermissions();
      print('[CallCubit] requestPermissions() returned $hasPermissions');
      if (!hasPermissions) {
        print('[CallCubit] initiateCall() ABORTED: permissions not granted');
        emit(CallErrorState('Microphone and camera permissions are required'));
        return;
      }

      print('[CallCubit] calling _webRTCService.initializeCall(isVideo=$isVideo)');
      await _webRTCService.initializeCall(isVideo);
      webRtcInitialized = true;
      print('[CallCubit] _webRTCService.initializeCall() complete');

      print('[CallCubit] calling _webRTCService.createOffer()');
      final offerSdp = await _webRTCService.createOffer();
      print('[CallCubit] createOffer() returned sdp of length=${offerSdp?.length}');
      if (offerSdp == null) {
        print('[CallCubit] initiateCall() ABORTED: offerSdp is null');
        await _webRTCService.hangUp();
        emit(CallErrorState('Failed to create call offer'));
        return;
      }

      print('[CallCubit] calling _callRepository.startCall()');
      final call = await _callRepository.startCall(
        callerId: callerId,
        calleeId: calleeId,
        isVideoCall: isVideo,
        sdpOffer: offerSdp,
      );
      print('[CallCubit] startCall() returned call.id=${call.id}');

      _currentCallId = call.id;
      print('[CallCubit] _currentCallId set to ${call.id}');

      print('[CallCubit] calling _webRTCService.listenForIceCandidates(${call.id})');
      _webRTCService.listenForIceCandidates(call.id);

      print('[CallCubit] calling _listenToCallUpdates(${call.id})');
      _listenToCallUpdates(call.id);

      print('[CallCubit] starting call timer');
      _startCallTimer();

      print('[CallCubit] emitting CallRingingState(callId=${call.id})');
      emit(CallRingingState(callId: call.id));
      print('[CallCubit] initiateCall() END (success)');
    } catch (e, st) {
      print('[CallCubit] initiateCall() EXCEPTION: $e');
      print(st);
      if (webRtcInitialized) {
        print('[CallCubit] releasing mic/camera after initiateCall() failure');
        await _webRTCService.hangUp();
      }
      _currentCallId = null;
      emit(CallErrorState(e.toString()));
    }
  }

  void _listenToCallUpdates(String callId) {
    print('[CallCubit] _listenToCallUpdates() called for callId=$callId');
    _callSubscription?.cancel();
    _callSubscription = _callRepository.listenToCall(callId).listen((call) {
      print('[CallCubit] call update event: id=${call.id}, status=${call.status}');

      if (_currentCallId != callId) {
        print('[CallCubit] ignored update: callId=$callId does not match _currentCallId=$_currentCallId');
        return;
      }

      switch (call.status) {
        case CallStatus.connecting:
          print('[CallCubit] status=connecting -> _handleCallConnecting');
          _handleCallConnecting(call);
          break;
        case CallStatus.connected:
          print('[CallCubit] status=connected -> _handleCallConnected');
          _handleCallConnected(call);
          break;
        case CallStatus.ended:
        case CallStatus.rejected:
        case CallStatus.missed:
          print('[CallCubit] status=${call.status.name} -> _handleCallEnded');
          _handleCallEnded(call.status.name);
          break;
        default:
          print('[CallCubit] status=${call.status} -> no handler (default)');
          break;
      }
    }, onError: (e, st) {
      print('[CallCubit] listenToCall($callId) stream ERROR: $e');
      print(st);
    });
    print('[CallCubit] _listenToCallUpdates() subscription set up for callId=$callId');
  }

  void _handleCallConnecting(CallEntity call) {
    print('[CallCubit] _handleCallConnecting() call.id=${call.id}, sdpAnswer present=${call.sdpAnswer != null}');
    if (call.sdpAnswer != null) {
      print('[CallCubit] calling _webRTCService.setRemoteDescription(type=answer)');
      _webRTCService.setRemoteDescription(call.sdpAnswer!, 'answer').then((_) {
        print('[CallCubit] setRemoteDescription(answer) complete');
      }).catchError((e, st) {
        print('[CallCubit] setRemoteDescription(answer) ERROR: $e');
        print(st);
      });
    }
  }

  void _handleCallConnected(CallEntity call) {
    print('[CallCubit] _handleCallConnected() call.id=${call.id}, current state=${state.runtimeType}');
    if (state is! CallConnectedState) {
      print('[CallCubit] cancelling call timer (connected)');
      _callTimer?.cancel();
      _callTimer = null;

      print('[CallCubit] emitting CallConnectedState');
      emit(CallConnectedState(
        callId: call.id,
        callerId: call.callerId,
        calleeId: call.calleeId,
        isVideo: call.isVideoCall,
      ));
    } else {
      print('[CallCubit] already CallConnectedState, skipping duplicate emit');
    }
  }

  void _handleCallEnded(String reason) {
    print('[CallCubit] _handleCallEnded() reason=$reason');
    emit(CallEndedState(reason: reason));
    _cleanupCall();
  }

  Future<void> acceptCall(String callId) async {
    print('[CallCubit] acceptCall() START callId=$callId');
    // Same tracking as initiateCall() — lets us release the mic/camera if
    // a step after initializeCall() throws.
    var webRtcInitialized = false;
    try {
      // Permission check was missing here before — acceptCall() went
      // straight to getUserMedia via initializeCall(), which would throw
      // an unhandled-ish platform exception instead of a clean error
      // state if mic/camera permission had been denied.
      final hasPermissions = await _webRTCService.requestPermissions();
      print('[CallCubit] requestPermissions() returned $hasPermissions');
      if (!hasPermissions) {
        print('[CallCubit] acceptCall() ABORTED: permissions not granted');
        emit(CallErrorState('Microphone and camera permissions are required'));
        return;
      }

      print('[CallCubit] fetching call row from supabase for id=$callId');
      final response =
      await _supabase.from('calls').select().eq('id', callId).single();
      print('[CallCubit] call row fetched: $response');

      _currentCallId = callId;
      print('[CallCubit] _currentCallId set to $callId');

      final isVideo = response['is_video_call'] ?? false;
      print('[CallCubit] calling _webRTCService.initializeCall(isVideo=$isVideo)');
      await _webRTCService.initializeCall(isVideo);
      webRtcInitialized = true;
      print('[CallCubit] _webRTCService.initializeCall() complete');

      print('[CallCubit] calling _webRTCService.setRemoteDescription(type=offer)');
      await _webRTCService.setRemoteDescription(
        response['sdp_offer'],
        'offer',
      );
      print('[CallCubit] setRemoteDescription(offer) complete');

      print('[CallCubit] calling _webRTCService.createAnswer()');
      final answerSdp = await _webRTCService.createAnswer();
      print('[CallCubit] createAnswer() returned sdp of length=${answerSdp?.length}');
      if (answerSdp == null) {
        print('[CallCubit] acceptCall() ABORTED: answerSdp is null');
        await _webRTCService.hangUp();
        _currentCallId = null;
        emit(CallErrorState('Failed to create answer'));
        return;
      }

      print('[CallCubit] calling _callRepository.answerCall()');
      await _callRepository.answerCall(
        callId: callId,
        sdpAnswer: answerSdp,
      );
      print('[CallCubit] answerCall() complete');

      print('[CallCubit] calling _callRepository.updateCallStatus(connecting)');
      await _callRepository.updateCallStatus(
        callId: callId,
        status: CallStatus.connecting,
      );
      print('[CallCubit] updateCallStatus(connecting) complete');

      print('[CallCubit] calling _webRTCService.listenForIceCandidates($callId)');
      _webRTCService.listenForIceCandidates(callId);

      print('[CallCubit] calling _listenToCallUpdates($callId)');
      _listenToCallUpdates(callId);

      print('[CallCubit] emitting CallAcceptedState(callId=$callId)');
      emit(CallAcceptedState(callId: callId));
      print('[CallCubit] acceptCall() END (success)');
    } catch (e, st) {
      print('[CallCubit] acceptCall() EXCEPTION: $e');
      print(st);
      if (webRtcInitialized) {
        print('[CallCubit] releasing mic/camera after acceptCall() failure');
        await _webRTCService.hangUp();
      }
      _currentCallId = null;
      emit(CallErrorState(e.toString()));
    }
  }

  Future<void> rejectCall(String callId) async {
    print('[CallCubit] rejectCall() START callId=$callId');
    try {
      await _callRepository.updateCallStatus(
        callId: callId,
        status: CallStatus.rejected,
      );
      print('[CallCubit] updateCallStatus(rejected) complete');

      emit(CallEndedState(reason: 'rejected'));
      _cleanupCall();
      print('[CallCubit] rejectCall() END (success)');
    } catch (e, st) {
      print('[CallCubit] rejectCall() EXCEPTION: $e');
      print(st);
      emit(CallErrorState(e.toString()));
    }
  }

  Future<void> endCall() async {
    print('[CallCubit] endCall() START _currentCallId=$_currentCallId');
    try {
      if (_currentCallId != null) {
        print('[CallCubit] updateCallStatus(ended) for $_currentCallId');
        await _callRepository.updateCallStatus(
          callId: _currentCallId!,
          status: CallStatus.ended,
        );
        print('[CallCubit] updateCallStatus(ended) complete');
      }

      // hangUp() used to be called here AND again inside _cleanupCall()
      // right below. Harmless (hangUp is idempotent) but redundant —
      // _cleanupCall() is the single place that tears down WebRTC now.
      emit(CallEndedState(reason: 'ended'));
      _cleanupCall();
      print('[CallCubit] endCall() END (success)');
    } catch (e, st) {
      print('[CallCubit] endCall() EXCEPTION: $e');
      print(st);
      emit(CallErrorState(e.toString()));
    }
  }

  void toggleMute() {
    print('[CallCubit] toggleMute() called');
    _webRTCService.toggleMute();
  }

  void toggleSpeaker() {
    print('[CallCubit] toggleSpeaker() called');
    _webRTCService.toggleSpeaker();
  }

  void switchCamera() {
    print('[CallCubit] switchCamera() called');
    _webRTCService.switchCamera();
  }

  void _startCallTimer() {
    print('[CallCubit] _startCallTimer() called (45s timeout)');
    _callTimer = Timer(const Duration(seconds: 45), () {
      print('[CallCubit] call timer fired. state=${state.runtimeType}, _currentCallId=$_currentCallId');
      if (state is CallRingingState && _currentCallId != null) {
        print('[CallCubit] marking call as missed: $_currentCallId');
        _callRepository.updateCallStatus(
          callId: _currentCallId!,
          status: CallStatus.missed,
        );
        emit(CallEndedState(reason: 'missed'));
        _cleanupCall();
      } else {
        print('[CallCubit] timer fired but call already progressed past ringing, no action');
      }
    });
  }

  void _cleanupCall() {
    print('[CallCubit] _cleanupCall() called');
    _callTimer?.cancel();
    _callTimer = null;
    _currentCallId = null;
    _callSubscription?.cancel();
    _callSubscription = null;
    _webRTCService.hangUp();
    print('[CallCubit] _cleanupCall() complete');
  }

  @override
  Future<void> close() {
    print('[CallCubit] close() called');
    _callTimer?.cancel();
    _callSubscription?.cancel();
    _incomingCallSubscription?.cancel();
    _iceSubscription?.cancel();
    _webRTCService.dispose();
    return super.close();
  }
}