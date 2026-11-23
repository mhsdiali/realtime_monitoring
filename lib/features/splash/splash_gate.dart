import 'package:flutter/material.dart';

import 'splash_page.dart';

class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _showSplash
          ? SplashPage(
              key: const ValueKey('splash'),
              onFinished: () {
                if (mounted) {
                  setState(() => _showSplash = false);
                }
              },
            )
          : KeyedSubtree(key: const ValueKey('app'), child: widget.child),
    );
  }
}
