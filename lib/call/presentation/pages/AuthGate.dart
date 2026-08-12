import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'contacts_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();

  bool _isLoading = true;
  bool _needsName = false;
  String? _error;

  static const _bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B0B14), Color(0xFF1A1030), Color(0xFF0B0B14)],
  );

  static const _accentGradient = LinearGradient(
    colors: [Color(0xFF7C4DFF), Color(0xFF3D5AFE)],
  );

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      var user = _supabase.auth.currentUser;
      if (user == null) {
        final response = await _supabase.auth.signInAnonymously();
        user = response.user;
      }

      if (user == null) {
        setState(() {
          _error = 'Could not sign in';
          _isLoading = false;
        });
        return;
      }

      final existing = await _supabase
          .from('users')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      setState(() {
        _needsName = existing == null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _supabase.from('users').insert({
        'id': user.id,
        'name': name,
        'is_online': true,
      }).select();
      setState(() {
        _needsName = false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _bgGradient),
        child: SafeArea(
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: _buildBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Column(
        key: const ValueKey('loading'),
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (r) => _accentGradient.createShader(r),
            child: const Icon(Icons.call, size: 56, color: Colors.white),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: Color(0xFF7C4DFF)),
          const SizedBox(height: 16),
          const Text('Setting things up…',
              style: TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      );
    }

    if (_error != null) {
      return Padding(
        key: const ValueKey('error'),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              'Something went wrong\n$_error',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _GradientButton(
              gradient: _accentGradient,
              label: 'Retry',
              onPressed: _bootstrap,
            ),
          ],
        ),
      );
    }

    if (_needsName) {
      return Padding(
        key: const ValueKey('name'),
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (r) => _accentGradient.createShader(r),
              child: const Icon(Icons.person_rounded, size: 56, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'What should we call you?',
              style: TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  hintText: 'Your name',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                  contentPadding:
                  EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                ),
                onSubmitted: (_) => _saveName(),
              ),
            ),
            const SizedBox(height: 24),
            _GradientButton(
              gradient: _accentGradient,
              label: 'Continue',
              onPressed: _saveName,
              fullWidth: true,
            ),
          ],
        ),
      );
    }

    return const ContactsScreen(key: ValueKey('contacts'));
  }
}

class _GradientButton extends StatelessWidget {
  final Gradient gradient;
  final String label;
  final VoidCallback onPressed;
  final bool fullWidth;

  const _GradientButton({
    required this.gradient,
    required this.label,
    required this.onPressed,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C4DFF).withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
      ),
    );
  }
}