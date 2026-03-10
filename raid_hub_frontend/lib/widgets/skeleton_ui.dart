import 'package:flutter/material.dart';

/// [SkeletonCard] 
/// 데이터 로딩 중에 표시되는 깜빡이는 카드 UI 위젯입니다.
/// ShimmerEffect와 결합하여 부드러운 로딩 경험을 제공합니다.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ShimmerEffect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(color: Colors.white10),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: double.infinity, height: 16, color: Colors.white10),
                    const SizedBox(height: 8),
                    Container(width: 150, height: 12, color: Colors.white10),
                    const SizedBox(height: 4),
                    Container(width: 100, height: 12, color: Colors.white10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [ShimmerEffect]
/// 자식 위젯(child)의 투명도를 조절하여 부드럽게 깜빡이는 애니메이션 효과를 주는 위젯입니다.
class ShimmerEffect extends StatefulWidget {
  final Widget child;
  const ShimmerEffect({super.key, required this.child});

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _animation, child: widget.child);
  }
}
