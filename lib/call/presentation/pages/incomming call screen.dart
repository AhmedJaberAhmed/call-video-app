import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/call_cubit.dart';
import 'active_call_screens.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerId;
  final String callerName;
  final bool isVideo;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.isVideo,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController =
    AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1030), Color(0xFF0B0B14)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                Text(
                  widget.isVideo ? 'Incoming Video Call' : 'Incoming Call',
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 36),
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
                            final t = (_pulseController.value + i * 0.5) % 1.0;
                            return Opacity(
                              opacity: (1 - t) * 0.4,
                              child: Transform.scale(
                                scale: 0.6 + t * 0.7,
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF7C4DFF),
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
                              color: const Color(0xFF7C4DFF).withOpacity(0.5),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.callerName.isNotEmpty
                              ? widget.callerName[0].toUpperCase()
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
                  widget.callerName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.isVideo
                          ? Icons.videocam_rounded
                          : Icons.call_rounded,
                      color: Colors.white54,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.isVideo ? 'Video call' : 'Voice call',
                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ],
                ),
                const Spacer(flex: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          _CallActionButton(
                            heroTag: 'reject',
                            icon: Icons.call_end_rounded,
                            gradient: const LinearGradient(
                                colors: [Color(0xFFFF1744), Color(0xFFD50000)]),
                            onPressed: () {
                              context.read<CallCubit>().rejectCall(widget.callId);
                              Navigator.pop(context);
                            },
                          ),
                          const SizedBox(height: 10),
                          const Text('Decline',
                              style: TextStyle(color: Colors.white54, fontSize: 13)),
                        ],
                      ),
                      Column(
                        children: [
                          _CallActionButton(
                            heroTag: 'accept',
                            icon: Icons.call_rounded,
                            gradient: const LinearGradient(
                                colors: [Color(0xFF00C853), Color(0xFF00E676)]),
                            onPressed: () async {
                              final cubit = context.read<CallCubit>();
                              await cubit.acceptCall(widget.callId);
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ActiveCallScreen(
                                    callId: widget.callId,
                                    isVideo: widget.isVideo,
                                    calleeName: widget.callerName,
                                    webRTCService: cubit.webRTCService,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          const Text('Accept',
                              style: TextStyle(color: Colors.white54, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final String heroTag;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onPressed;

  const _CallActionButton({
    required this.heroTag,
    required this.icon,
    required this.gradient,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (gradient as LinearGradient).colors.last.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: FloatingActionButton(
        heroTag: heroTag,
        onPressed: onPressed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Ink(
          decoration: BoxDecoration(gradient: gradient, shape: BoxShape.circle),
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(icon, size: 28, color: Colors.white),
          ),
        ),
      ),
    );
  }
}