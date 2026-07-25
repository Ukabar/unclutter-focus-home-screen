import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/brand/stillscreen_logo.dart';
import '../core/theme/app_theme.dart';
import '../features/essential_apps/widgets/premium_components.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.onFinish, super.key});

  final VoidCallback onFinish;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const List<_OnboardingPageData> _pages = <_OnboardingPageData>[
    _OnboardingPageData(
      title: 'Welcome to Stillscreen',
      body: 'A quiet launcher for the few apps that deserve your attention.',
      icon: CupertinoIcons.sparkles,
    ),
    _OnboardingPageData(
      title: 'Why minimal?',
      body: 'A shorter first screen creates fewer loops and cleaner choices.',
      icon: CupertinoIcons.circle_grid_3x3_fill,
    ),
    _OnboardingPageData(
      title: 'How it works',
      body:
          'Choose essential apps, arrange the order, and keep the rest out of sight.',
      icon: CupertinoIcons.slider_horizontal_3,
    ),
    _OnboardingPageData(
      title: 'Widget companion',
      body: 'Your Widget reads the same ordered list through the App Group.',
      icon: CupertinoIcons.rectangle_grid_2x2_fill,
    ),
    _OnboardingPageData(
      title: 'Start with a few',
      body: 'Pick your first apps now. You can edit, reorder, or reset later.',
      icon: CupertinoIcons.check_mark_circled,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _pages.length - 1) {
      widget.onFinish();
      return;
    }

    _controller.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return PremiumScaffoldBand(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compactHeight = constraints.maxHeight < 700;
              final double horizontalPadding = constraints.maxWidth < 390
                  ? 20
                  : 24;
              final double verticalPadding = compactHeight ? 14 : 20;

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  verticalPadding,
                  horizontalPadding,
                  verticalPadding,
                ),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const StillscreenLogo(size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Stillscreen',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: widget.onFinish,
                          child: const Text('Skip'),
                        ),
                      ],
                    ),
                    SizedBox(height: compactHeight ? 8 : 14),
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: _pages.length,
                        onPageChanged: (int value) {
                          setState(() => _index = value);
                        },
                        itemBuilder: (BuildContext context, int index) {
                          return _AnimatedOnboardingPage(
                            controller: _controller,
                            index: index,
                            child: _OnboardingPage(data: _pages[index]),
                          );
                        },
                      ),
                    ),
                    _ProgressDots(count: _pages.length, index: _index),
                    SizedBox(height: compactHeight ? 14 : 18),
                    _OnboardingButton(
                      label: _index == _pages.length - 1 ? 'Finish' : 'Next',
                      icon: _index == _pages.length - 1
                          ? CupertinoIcons.check_mark
                          : CupertinoIcons.arrow_right,
                      onPressed: _next,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AnimatedOnboardingPage extends StatelessWidget {
  const _AnimatedOnboardingPage({
    required this.controller,
    required this.index,
    required this.child,
  });

  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (BuildContext context, Widget? child) {
        final double page = controller.hasClients
            ? controller.page ?? index.toDouble()
            : index.toDouble();
        final double distance = (page - index).abs().clamp(0.0, 1.0);
        final double opacity = 1 - (distance * 0.32);
        final double slide = 18 * distance;

        return Opacity(
          opacity: opacity,
          child: Transform.translate(offset: Offset(0, slide), child: child),
        );
      },
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compactHeight = constraints.maxHeight < 560;
        final double iconBoxSize = compactHeight ? 88 : 99;
        final double iconSize = compactHeight ? 52 : 60;
        final double titleGap = compactHeight ? 20 : 24;

        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: iconBoxSize,
                  height: iconBoxSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(iconBoxSize * 0.30),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Icon(
                    data.icon,
                    color: AppTheme.accent,
                    size: iconSize,
                  ),
                ),
                SizedBox(height: titleGap),
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Text(
                    data.body,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.ivory.withValues(alpha: 0.82),
                      height: 1.38,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final Color activeColor = Theme.of(context).colorScheme.primary;
    final Color inactiveColor = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.28);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(count, (int item) {
        final bool isActive = item == index;
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(end: isActive ? 1 : 0),
          builder: (BuildContext context, double value, Widget? child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 7 + (20 * value),
              height: 7,
              decoration: BoxDecoration(
                color: Color.lerp(inactiveColor, activeColor, value),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          },
        );
      }),
    );
  }
}

class _OnboardingButton extends StatefulWidget {
  const _OnboardingButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  State<_OnboardingButton> createState() => _OnboardingButtonState();
}

class _OnboardingButtonState extends State<_OnboardingButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: widget.onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              textStyle: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(widget.label),
                const SizedBox(width: 10),
                Icon(widget.icon, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;
}
