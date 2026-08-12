
abstract class CallState {}

class CallInitial extends CallState {}

class CallConnectingState extends CallState {}

class CallRingingState extends CallState {
  final String callId;
  CallRingingState({required this.callId});
}

class IncomingCallState extends CallState {
  final String callId;
  final String callerId;
  final String calleeId;
  final bool isVideo;
  final String callerName;

  IncomingCallState({
    required this.callId,
    required this.callerId,
    required this.calleeId,
    required this.isVideo,
    required this.callerName,
  });
}

class CallAcceptedState extends CallState {
  final String callId;
  CallAcceptedState({required this.callId});
}

class CallConnectedState extends CallState {
  final String callId;
  final String callerId;
  final String calleeId;
  final bool isVideo;

  CallConnectedState({
    required this.callId,
    required this.callerId,
    required this.calleeId,
    required this.isVideo,
  });
}

class CallEndedState extends CallState {
  final String reason;
  CallEndedState({required this.reason});
}

class CallErrorState extends CallState {
  final String message;
  CallErrorState(this.message);
}