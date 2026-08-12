import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../data/webrtc_service.dart';
import '../cubits/call_cubit.dart';
import '../cubits/call_state.dart';

class ActiveCallScreen extends StatefulWidget {
  final String callId;
  final bool isVideo;
  final String calleeName;
  final WebRTCService webRTCService;

  const ActiveCallScreen({
    super.key,
    required this.callId,
    required this.isVideo,
    required this.calleeName,
    required this.webRTCService,
  });

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  late final WebRTCService _webRTCService = widget.webRTCService;
  String _callDuration = '00:00';
  Timer? _timer;
  int _seconds = 0;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isNavigatingAway = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _listenForRemoteStream();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
        final minutes = (_seconds ~/ 60).toString().padLeft(2, '0');
        final seconds = (_seconds % 60).toString().padLeft(2, '0');
        _callDuration = '$minutes:$seconds';
      });
    });
  }

  void _listenForRemoteStream() {
    _webRTCService.remoteStream.listen((stream) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Previously this screen had no BlocListener at all, so if the other
    // side hung up, rejected, or the call errored out while you were
    // already here, nothing told this screen to close — you'd be stuck
    // looking at an active call UI with a dead connection.
    return BlocListener<CallCubit, CallState>(
      listener: (context, state) {
        if (_isNavigatingAway) return;
        if (state is CallEndedState || state is CallErrorState) {
          _isNavigatingAway = true;
          if (state is CallErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        context.read<CallCubit>().endCall();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF7C4DFF),
                      child: Text(
                        widget.calleeName.isNotEmpty
                            ? widget.calleeName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.calleeName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF00E676),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _callDuration,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: widget.isVideo
                    ? _buildVideoCallView()
                    : _buildAudioCallView(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      active: _isMuted,
                      onPressed: () {
                        setState(() => _isMuted = !_isMuted);
                        context.read<CallCubit>().toggleMute();
                      },
                    ),
                    _buildControlButton(
                      icon: _isSpeakerOn
                          ? Icons.volume_up
                          : Icons.volume_down_rounded,
                      active: _isSpeakerOn,
                      onPressed: () {
                        setState(() => _isSpeakerOn = !_isSpeakerOn);
                        context.read<CallCubit>().toggleSpeaker();
                      },
                    ),
                    _buildEndCallButton(
                      onPressed: () {
                        context.read<CallCubit>().endCall();
                        Navigator.pop(context);
                      },
                    ),
                    if (widget.isVideo)
                      _buildControlButton(
                        icon: Icons.cameraswitch_rounded,
                        active: false,
                        onPressed: () {
                          context.read<CallCubit>().switchCamera();
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCallView() {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFF111111),
          child: RTCVideoView(
            _webRTCService.remoteRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            width: 110,
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: RTCVideoView(
                _webRTCService.localRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                mirror: true,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioCallView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1030), Colors.black],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: [Color(0xFF7C4DFF), Color(0xFF3D5AFE)]),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C4DFF).withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                widget.calleeName.isNotEmpty
                    ? widget.calleeName[0].toUpperCase()
                    : '?',
                style: const TextStyle(fontSize: 54, color: Colors.white),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              widget.calleeName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _callDuration,
              style: const TextStyle(color: Colors.white54, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool active,
    VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: active ? Colors.black : Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildEndCallButton({required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withOpacity(0.5),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Ink(
            decoration: const BoxDecoration(
              gradient:
              LinearGradient(colors: [Color(0xFFFF1744), Color(0xFFD50000)]),
              shape: BoxShape.circle,
            ),
            child: const SizedBox(
              width: 68,
              height: 68,
              child: Icon(Icons.call_end_rounded, size: 30, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}