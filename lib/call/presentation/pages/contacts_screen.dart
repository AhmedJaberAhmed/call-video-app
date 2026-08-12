import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cubits/call_cubit.dart';
import '../cubits/call_state.dart';
import 'OutgoingCallScreen.dart';
import 'incomming call screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;
  String? _error;

  static const _bg = Color(0xFF0B0B14);
  static const _accentGradient =
  LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF3D5AFE)]);

  @override
  void initState() {
    super.initState();
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<CallCubit>().initialize(currentUserId);
      });
    }
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    try {
      final response =
      await _supabase.from('users').select().neq('id', currentUserId ?? '');
      if (!mounted) return;
      setState(() {
        _contacts = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _startCall(Map<String, dynamic> contact, bool isVideo) {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OutgoingCallScreen(
          callerId: currentUserId,
          calleeId: contact['id'] as String,
          calleeName: contact['name'] as String? ?? 'Unknown',
          isVideoCall: isVideo,
        ),
      ),
    );
  }

  Color _avatarColor(String seed) {
    final colors = [
      const Color(0xFF7C4DFF),
      const Color(0xFF3D5AFE),
      const Color(0xFF00BFA5),
      const Color(0xFFFF6D00),
      const Color(0xFFD500F9),
      const Color(0xFF00B8D4),
    ];
    final idx = seed.isEmpty ? 0 : seed.codeUnitAt(0) % colors.length;
    return colors[idx];
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CallCubit, CallState>(
      listener: (context, state) {
        if (state is IncomingCallState) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IncomingCallScreen(
                callId: state.callId,
                callerId: state.callerId,
                callerName: state.callerName,
                isVideo: state.isVideo,
              ),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: _bg,
              pinned: true,
              expandedHeight: 120,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                title: const Text(
                  'Contacts',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22),
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1A1030), _bg],
                    ),
                  ),
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                    child:
                    CircularProgressIndicator(color: Color(0xFF7C4DFF))),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'Failed to load contacts: $_error',
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (_contacts.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Text('No contacts found',
                        style: TextStyle(color: Colors.white38, fontSize: 15)),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final contact = _contacts[index];
                        final name = contact['name'] as String? ?? 'Unknown';
                        final isOnline = contact['is_online'] as bool? ?? false;
                        final color = _avatarColor(name);

                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: color,
                                    child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18),
                                    ),
                                  ),
                                  if (isOnline)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 13,
                                        height: 13,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00E676),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: _bg, width: 2.5),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(
                                      isOnline ? 'Online' : 'Offline',
                                      style: TextStyle(
                                          color: isOnline
                                              ? const Color(0xFF00E676)
                                              : Colors.white38,
                                          fontSize: 12.5),
                                    ),
                                  ],
                                ),
                              ),
                              _CircleIconButton(
                                icon: Icons.call_rounded,
                                gradient: const LinearGradient(colors: [
                                  Color(0xFF00C853),
                                  Color(0xFF00E676)
                                ]),
                                onPressed: () => _startCall(contact, false),
                              ),
                              const SizedBox(width: 10),
                              _CircleIconButton(
                                icon: Icons.videocam_rounded,
                                gradient: _accentGradient,
                                onPressed: () => _startCall(contact, true),
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: _contacts.length,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onPressed;

  const _CircleIconButton({
    required this.icon,
    required this.gradient,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(gradient: gradient, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}