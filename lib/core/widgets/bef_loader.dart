import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class BEFLoader extends StatefulWidget {
  final double size;
  const BEFLoader({super.key, this.size = 80});

  @override
  State<BEFLoader> createState() => _BEFLoaderState();
}

class _BEFLoaderState extends State<BEFLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The "BEF" Text
          Text(
            'BEF',
            style: TextStyle(
              fontSize: widget.size * 0.3,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
              letterSpacing: 1.2,
            ),
          ),
          // The Rotating Circle
          RotationTransition(
            turns: _controller,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primary.withOpacity(0.8),
                ),
                backgroundColor: AppColors.primary.withOpacity(0.1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FullScreenLoader extends StatelessWidget {
  const FullScreenLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: BEFLoader(size: 100),
    );
  }
}
