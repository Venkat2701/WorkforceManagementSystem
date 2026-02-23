import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../features/auth/login_screen.dart';

class SessionTimeoutWrapper extends ConsumerStatefulWidget {
  final Widget child;
  final Duration timeout;
  final GlobalKey<NavigatorState> navigatorKey;

  const SessionTimeoutWrapper({
    super.key,
    required this.child,
    required this.navigatorKey,
    this.timeout = const Duration(minutes: 30),
  });

  @override
  ConsumerState<SessionTimeoutWrapper> createState() => _SessionTimeoutWrapperState();
}

class _SessionTimeoutWrapperState extends ConsumerState<SessionTimeoutWrapper> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  void _resetTimer() {
    _timer?.cancel();
    // Only start/reset timer if we have an active session
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      _timer = Timer(widget.timeout, _handleTimeout);
    }
  }

  // Listen to auth state changes to start/stop timer
  void _setupAuthListener() {
    ref.listen(authStateProvider, (previous, next) {
      if (next.value != null) {
        _resetTimer();
      } else {
        _timer?.cancel();
      }
    });
  }

  void _handleTimeout() async {
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      // User is logged in and inactive for 30 mins
      await ref.read(authServiceProvider).signOut();
      
      // The MyApp home will automatically switch to LoginScreen due to authStateProvider change
      // But we can force a navigation cleanup just in case
      widget.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      
      final scaffoldContext = widget.navigatorKey.currentContext;
      if (scaffoldContext != null) {
        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          const SnackBar(
            content: Text('You have been logged out due to inactivity.'),
            duration: Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This allows us to start the timer as soon as the user logs in
    _setupAuthListener();

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      onPointerUp: (_) => _resetTimer(),
      onPointerHover: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}
