import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SKELETON / SHIMMER LOADING WIDGETS
// Replaces basic CircularProgressIndicator with content-aware placeholders.
// ═══════════════════════════════════════════════════════════════════════════════

/// Shimmer animation wrapper — children pulsate with a subtle highlight sweep.
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  const ShimmerLoading({super.key, required this.child});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant;
    final highlight = isDark ? AppColors.borderDark : AppColors.border;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            colors: [base, highlight, base],
            stops: [
              (_anim.value - 0.3).clamp(0.0, 1.0),
              _anim.value,
              (_anim.value + 0.3).clamp(0.0, 1.0),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Single rectangular skeleton bone.
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Skeleton mimicking a list-tile card row.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SkeletonBox(width: 44, height: 44, borderRadius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(height: 14, width: MediaQuery.of(context).size.width * 0.3),
                  const SizedBox(height: 8),
                  const SkeletonBox(height: 10, width: 160),
                ],
              ),
            ),
            const SkeletonBox(width: 60, height: 24, borderRadius: 12),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for a KPI card grid.
class SkeletonKpiRow extends StatelessWidget {
  final int count;
  const SkeletonKpiRow({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
          child: const SkeletonBox(height: 100, borderRadius: 16),
        ),
      )),
    );
  }
}

/// Full-page dashboard skeleton.
class SkeletonDashboard extends StatelessWidget {
  const SkeletonDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: AppSpace.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonKpiRow(),
            const SizedBox(height: 20),
            const SkeletonBox(height: 14, width: 120),
            const SizedBox(height: 12),
            ...List.generate(3, (_) => const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: SkeletonCard(),
            )),
          ],
        ),
      ),
    );
  }
}

/// Full-page list skeleton (e.g. for pond list, task list, etc.).
class SkeletonListPage extends StatelessWidget {
  final int itemCount;
  const SkeletonListPage({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: AppSpace.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const SkeletonBox(height: 18, width: 140),
                const Spacer(),
                SkeletonBox(height: 36, width: 100, borderRadius: AppSizes.borderRadius),
              ],
            ),
            const SizedBox(height: 16),
            // Filter bar
            const Row(children: [
              SkeletonBox(height: 36, width: 180, borderRadius: 20),
              SizedBox(width: 8),
              SkeletonBox(height: 36, width: 100, borderRadius: 20),
            ]),
            const SizedBox(height: 16),
            // List items
            ...List.generate(itemCount, (_) => const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: SkeletonCard(),
            )),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for tab-based pages (warehouse, reports, payment).
class SkeletonTabPage extends StatelessWidget {
  const SkeletonTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: AppSpace.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            const Row(children: [
              SkeletonBox(height: 20, width: 160),
              Spacer(),
              SkeletonBox(height: 32, width: 32, borderRadius: 8),
              SizedBox(width: 8),
              SkeletonBox(height: 32, width: 32, borderRadius: 8),
            ]),
            const SizedBox(height: 16),
            // Tab bar
            const SkeletonBox(height: 44, borderRadius: 12),
            const SizedBox(height: 16),
            // Cards
            ...List.generate(4, (_) => const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: SkeletonCard(),
            )),
          ],
        ),
      ),
    );
  }
}
