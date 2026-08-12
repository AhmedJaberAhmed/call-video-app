import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_session/audio_session.dart';

import 'call/data/call_remote_datasource.dart';
import 'call/data/call_repository_impl.dart';
import 'call/data/webrtc_service.dart';
import 'call/presentation/cubits/call_cubit.dart';
import 'call/presentation/pages/AuthGate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  await Supabase.initialize(
    url: ' ',
    publishableKey: ' ',
  );


  await _requestPermissions();


  await _setupAudioSession();



  runApp(const MyApp());
}

Future<void> _requestPermissions() async {
  await [
    Permission.microphone,
    Permission.camera,
  ].request();
}

Future<void> _setupAudioSession() async {
  try {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionMode: AVAudioSessionMode.voiceChat,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth |
      AVAudioSessionCategoryOptions.defaultToSpeaker |
      AVAudioSessionCategoryOptions.allowAirPlay,
    ));
  } catch (e) {
    print('Audio session setup error: $e');
  }
}

// Uncomment this if you want to insert test users
// Future<void> _insertTestUsers() async {
//   final supabase = Supabase.instance.client;
//
//   // Check if users exist
//   final existing = await supabase
//       .from('users')
//       .select('id')
//       .inFilter('id', [
//         '11111111-1111-1111-1111-111111111111',
//         '22222222-2222-2222-2222-222222222222',
//       ]);
//
//   if (existing.isEmpty) {
//     await supabase.from('users').insert([
//       {
//         'id': '11111111-1111-1111-1111-111111111111',
//         'name': 'John Doe',
//         'email': 'john@example.com',
//         'is_online': true,
//       },
//       {
//         'id': '22222222-2222-2222-2222-222222222222',
//         'name': 'Jane Smith',
//         'email': 'jane@example.com',
//         'is_online': true,
//       },
//       {
//         'id': '33333333-3333-3333-3333-333333333333',
//         'name': 'Bob Wilson',
//         'email': 'bob@example.com',
//         'is_online': false,
//       },
//     ]);
//   }
// }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final remoteDataSource = CallRemoteDataSourceImpl(supabase);
    final repository = CallRepositoryImpl(remoteDataSource);
    final webRTCService = WebRTCService();

    return BlocProvider(
      create: (context) => CallCubit(
        callRepository: repository,
        webRTCService: webRTCService,
        supabase: supabase,
      ),
      child: MaterialApp(debugShowCheckedModeBanner: false,
        title: 'Call App',
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Colors.black,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

// Test user IDs you can use:
const String johnDoeId = '11111111-1111-1111-1111-111111111111';
const String janeSmithId = '22222222-2222-2222-2222-222222222222';
const String bobWilsonId = '33333333-3333-3333-3333-333333333333';

// Test call IDs:
const String connectedCallId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const String endedCallId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
const String ringingCallId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';