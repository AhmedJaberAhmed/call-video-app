import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WebRTCService {
  final SupabaseClient _supabase = Supabase.instance.client;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  final StreamController<MediaStream> _remoteStreamController =
  StreamController<MediaStream>.broadcast();

  String? _userId;
  String? _currentCallId;
  RealtimeChannel? _iceChannel;
  bool _isMuted = false;
  bool _isSpeakerOn = false;

  final List<RTCIceCandidate> _pendingCandidates = [];
  bool _remoteDescriptionSet = false;

 
  void Function()? onConnected;
  bool _connectedFired = false;

  Stream<MediaStream> get remoteStream => _remoteStreamController.stream;
  MediaStream? get localStream => _localStream;
  RTCVideoRenderer get localRenderer => _localRenderer;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;

  static const Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
     
    ],
  };

  void initialize(String userId) {
    print('[WebRTCService] initialize() userId=$userId');
    _userId = userId;
  }

  Future<bool> requestPermissions() async {
    print('[WebRTCService] requestPermissions() requesting mic+camera');
    try {
      final statuses = await [
        Permission.microphone,
        Permission.camera,
      ].request();
      print('[WebRTCService] permission statuses: mic=${statuses[Permission.microphone]}, camera=${statuses[Permission.camera]}');
      return statuses[Permission.microphone]!.isGranted;
    } catch (e, st) {
      print('[WebRTCService] requestPermissions() ERROR: $e');
      print(st);
      return false;
    }
  }

  Future<void> initializeRenderers() async {
    print('[WebRTCService] initializeRenderers() START');
    try {
      await _localRenderer.initialize();
      print('[WebRTCService] localRenderer initialized');
      await _remoteRenderer.initialize();
      print('[WebRTCService] remoteRenderer initialized');
    } catch (e, st) {
      print('[WebRTCService] initializeRenderers() ERROR: $e');
      print(st);
      rethrow;
    }
  }

  Future<void> initializeCall(bool isVideo) async {
    print('[WebRTCService] initializeCall(isVideo=$isVideo) START');
    _remoteDescriptionSet = false;
    _connectedFired = false;
    try {
      await initializeRenderers();

      print('[WebRTCService] creating peer connection with iceServers=$_iceServers');
      _peerConnection = await createPeerConnection(_iceServers);
      print('[WebRTCService] peer connection created: $_peerConnection');

      print('[WebRTCService] requesting getUserMedia (audio=true, video=$isVideo)');
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': isVideo
            ? {
          'facingMode': 'user',
          'width': 640,
          'height': 480,
        }
            : false,
      });
      print('[WebRTCService] getUserMedia() succeeded, stream id=${_localStream?.id}');

      if (isVideo) {
        _localRenderer.srcObject = _localStream;
        print('[WebRTCService] localRenderer.srcObject set');
      }

      for (final track in _localStream!.getTracks()) {
        print('[WebRTCService] adding track kind=${track.kind} id=${track.id}');
        await _peerConnection!.addTrack(track, _localStream!);
      }
      print('[WebRTCService] all local tracks added to peer connection');

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        print('[WebRTCService] onTrack event fired, streams.length=${event.streams.length}');
        if (event.streams.isNotEmpty) {
          final stream = event.streams[0];
          print('[WebRTCService] remote stream received, id=${stream.id}');
          _remoteRenderer.srcObject = stream;
          _remoteStreamController.add(stream);
        } else {
          print('[WebRTCService] onTrack event had no streams');
        }
      };

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        print('[WebRTCService] onIceCandidate fired: candidate=${candidate.candidate}');
        if (candidate.candidate == null) {
          print('[WebRTCService] skipped null candidate');
          return;
        }

        if (_currentCallId != null) {
          _sendCandidate(_currentCallId!, candidate);
        } else {
          print('[WebRTCService] no currentCallId yet, buffering candidate (buffer size will be ${_pendingCandidates.length + 1})');
          _pendingCandidates.add(candidate);
        }
      };

      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        print('[WebRTCService] onIceConnectionState: $state');
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        print('[WebRTCService] onConnectionState: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
            !_connectedFired) {
          _connectedFired = true;
          print('[WebRTCService] peer connection CONNECTED, firing onConnected callback');
          onConnected?.call();
        }
      };

      _peerConnection!.onIceGatheringState = (RTCIceGatheringState state) {
        print('[WebRTCService] onIceGatheringState: $state');
      };

      _peerConnection!.onSignalingState = (RTCSignalingState state) {
        print('[WebRTCService] onSignalingState: $state');
      };

      print('[WebRTCService] initializeCall() END (success)');
    } catch (e, st) {
      print('[WebRTCService] initializeCall() EXCEPTION: $e');
      print(st);
      rethrow;
    }
  }

  Future<String?> createOffer() async {
    print('[WebRTCService] createOffer() START, peerConnection null=${_peerConnection == null}');
    if (_peerConnection == null) {
      print('[WebRTCService] createOffer() ABORTED: peerConnection is null');
      return null;
    }
    try {
      final offer = await _peerConnection!.createOffer();
      print('[WebRTCService] createOffer() offer created, type=${offer.type}');
      await _peerConnection!.setLocalDescription(offer);
      print('[WebRTCService] setLocalDescription(offer) complete');
      return offer.sdp;
    } catch (e, st) {
      print('[WebRTCService] createOffer() EXCEPTION: $e');
      print(st);
      return null;
    }
  }

  Future<String?> createAnswer() async {
    print('[WebRTCService] createAnswer() START, peerConnection null=${_peerConnection == null}');
    if (_peerConnection == null) {
      print('[WebRTCService] createAnswer() ABORTED: peerConnection is null');
      return null;
    }
    try {
      final answer = await _peerConnection!.createAnswer();
      print('[WebRTCService] createAnswer() answer created, type=${answer.type}');
      await _peerConnection!.setLocalDescription(answer);
      print('[WebRTCService] setLocalDescription(answer) complete');
      return answer.sdp;
    } catch (e, st) {
      print('[WebRTCService] createAnswer() EXCEPTION: $e');
      print(st);
      return null;
    }
  }

  Future<void> setRemoteDescription(String sdp, String type) async {
    print('[WebRTCService] setRemoteDescription(type=$type) START, peerConnection null=${_peerConnection == null}, sdp length=${sdp.length}');
    if (_peerConnection == null) {
      print('[WebRTCService] setRemoteDescription() ABORTED: peerConnection is null');
      return;
    }
    if (_remoteDescriptionSet) {
      print('[WebRTCService] setRemoteDescription(type=$type) SKIPPED: remote description was already set for this call (duplicate event)');
      return;
    }
    try {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdp, type),
      );
      _remoteDescriptionSet = true;
      print('[WebRTCService] setRemoteDescription(type=$type) complete');
    } catch (e, st) {
      print('[WebRTCService] setRemoteDescription(type=$type) EXCEPTION: $e');
      print(st);
      rethrow;
    }
  }

  void _sendCandidate(String callId, RTCIceCandidate candidate) {
    print('[WebRTCService] inserting ice candidate for callId=$callId');
    _supabase.from('ice_candidates').insert({
      'call_id': callId,
      'sender_id': _userId,
      'candidate': {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      },
    }).then((_) {
      print('[WebRTCService] ice candidate insert succeeded');
    }).catchError((e, st) {
      print('[WebRTCService] ice candidate insert ERROR: $e');
      print(st);
    });
  }

  void listenForIceCandidates(String callId) {
    print('[WebRTCService] listenForIceCandidates(callId=$callId) START');
    _currentCallId = callId;

    if (_pendingCandidates.isNotEmpty) {
      print('[WebRTCService] flushing ${_pendingCandidates.length} buffered candidate(s) for callId=$callId');
      for (final candidate in _pendingCandidates) {
        _sendCandidate(callId, candidate);
      }
      _pendingCandidates.clear();
    } else {
      print('[WebRTCService] no buffered candidates to flush');
    }

    _iceChannel = _supabase.channel('ice_candidates_$callId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'ice_candidates',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'call_id',
          value: callId,
        ),
        callback: (payload) {
          print('[WebRTCService] ice_candidates INSERT event received');
          final record = payload.newRecord;
          if (record['sender_id'] == _userId) {
            print('[WebRTCService] ignored own ice candidate (sender_id=${record['sender_id']})');
            return;
          }
          final candidateData = record['candidate'] as Map<String, dynamic>;
          print('[WebRTCService] adding remote ice candidate: $candidateData');
          _peerConnection?.addCandidate(
            RTCIceCandidate(
              candidateData['candidate'] as String?,
              candidateData['sdpMid'] as String?,
              candidateData['sdpMLineIndex'] as int?,
            ),
          ).then((_) {
            print('[WebRTCService] addCandidate() succeeded');
          }).catchError((e, st) {
            print('[WebRTCService] addCandidate() ERROR: $e');
            print(st);
          });
        },
      )
      ..subscribe((status, error) {
        print('[WebRTCService] ice channel subscribe status=$status error=$error');
      });
    print('[WebRTCService] listenForIceCandidates() subscription set up for callId=$callId');
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    print('[WebRTCService] toggleMute() -> _isMuted=$_isMuted');
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
      print('[WebRTCService] audio track ${track.id} enabled=${track.enabled}');
    });
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    print('[WebRTCService] toggleSpeaker() -> _isSpeakerOn=$_isSpeakerOn');
    Helper.setSpeakerphoneOn(_isSpeakerOn);
  }

  Future<void> hangUp() async {
    print('[WebRTCService] hangUp() START');
    try {
      await _iceChannel?.unsubscribe();
      print('[WebRTCService] ice channel unsubscribed');
      _iceChannel = null;

      _localStream?.getTracks().forEach((track) {
        print('[WebRTCService] stopping local track ${track.id}');
        track.stop();
      });
      await _localStream?.dispose();
      print('[WebRTCService] local stream disposed');
      _localStream = null;

      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
      print('[WebRTCService] renderers cleared');

      await _peerConnection?.close();
      print('[WebRTCService] peer connection closed');
      await _peerConnection?.dispose();
      print('[WebRTCService] peer connection disposed');
      _peerConnection = null;

      _currentCallId = null;
      _remoteDescriptionSet = false;
      _connectedFired = false;

      if (_pendingCandidates.isNotEmpty) {
        print('[WebRTCService] discarding ${_pendingCandidates.length} unsent buffered candidate(s)');
        _pendingCandidates.clear();
      }

      print('[WebRTCService] hangUp() END (success)');
    } catch (e, st) {
      print('[WebRTCService] hangUp() EXCEPTION: $e');
      print(st);
    }
  }

  Future<void> dispose() async {
    print('[WebRTCService] dispose() START');
    await hangUp();
    await _localRenderer.dispose();
    print('[WebRTCService] localRenderer disposed');
    await _remoteRenderer.dispose();
    print('[WebRTCService] remoteRenderer disposed');
    await _remoteStreamController.close();
    print('[WebRTCService] dispose() END');
  }

  Future<void> switchCamera() async {
    print('[WebRTCService] switchCamera() START, localStream null=${_localStream == null}');
    if (_localStream == null) {
      print('[WebRTCService] switchCamera() ABORTED: no local stream');
      return;
    }
    final videoTracks = _localStream!.getVideoTracks();
    print('[WebRTCService] videoTracks.length=${videoTracks.length}');
    if (videoTracks.isEmpty) {
      print('[WebRTCService] switchCamera() ABORTED: no video tracks');
      return;
    }

    try {
      await videoTracks[0].switchCamera();
      print('[WebRTCService] switchCamera() succeeded');
    } catch (e, st) {
      print('[WebRTCService] switchCamera() EXCEPTION: $e');
      print(st);
    }
  }
}
