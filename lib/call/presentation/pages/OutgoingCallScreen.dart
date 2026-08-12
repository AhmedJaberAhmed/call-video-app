import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/call_cubit.dart';
import '../cubits/call_state.dart';
import 'active_call_screens.dart';

class OutgoingCallScreen extends StatefulWidget {
  final String callerId;
  final String calleeId;
  final String calleeName;
  final bool isVideoCall;

  const OutgoingCallScreen({
    super.key,
    required this.callerId,
    required this.calleeId,
    required this.calleeName,
    required this.isVideoCall,
  });

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController =
    AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CallCubit>().initiateCall(
        callerId: widget.callerId,
        calleeId: widget.calleeId,
        isVideo: widget.isVideoCall,
        calleeName: widget.calleeName,
      );
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1030), Color(0xFF0B0B14)],
          ),
        ),
        child: SafeArea(
          child: BlocConsumer<CallCubit, CallState>(
            listener: (context, state) {
              if (state is CallConnectedState) {
                final webRTCService = context.read<CallCubit>().webRTCService;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActiveCallScreen(
                      callId: state.callId,
                      isVideo: state.isVideo,
                      calleeName: widget.calleeName,
                      webRTCService: webRTCService,
                    ),
                  ),
                );
              } else if (state is CallEndedState) {
                Navigator.pop(context);
              } else if (state is CallErrorState) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.message)),
                );
                Navigator.pop(context);
              }
            },
            builder: (context, state) {
              return Column(
                children: [
                  const Spacer(flex: 2),
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ...List.generate(2, (i) {
                          return AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              final t =
                                  (_pulseController.value + i * 0.5) % 1.0;
                              return Opacity(
                                opacity: (1 - t) * 0.35,
                                child: Transform.scale(
                                  scale: 0.6 + t * 0.7,
                                  child: Container(
                                    width: 140,
                                    height: 140,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF3D5AFE),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                                colors: [Color(0xFF7C4DFF), Color(0xFF3D5AFE)]),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3D5AFE).withOpacity(0.4),
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
                            style: const TextStyle(
                                fontSize: 46,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    widget.calleeName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    state is CallConnectingState ? 'Calling…' : 'Ringing…',
                    style: const TextStyle(color: Colors.white54, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.isVideoCall
                            ? Icons.videocam_rounded
                            : Icons.call_rounded,
                        color: Colors.white38,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.isVideoCall ? 'Video call' : 'Voice call',
                        style:
                        const TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ],
                  ),
                  const Spacer(flex: 3),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: FloatingActionButton(
                      onPressed: () {
                        context.read<CallCubit>().endCall();
                      },
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      child: Ink(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                              colors: [Color(0xFFFF1744), Color(0xFFD50000)]),
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox(
                          width: 56,
                          height: 56,
                          child: Icon(Icons.call_end_rounded,
                              size: 28, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}