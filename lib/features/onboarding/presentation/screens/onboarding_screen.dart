import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/components/premium_primary_button.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  static const Duration _kPageTransition = Duration(milliseconds: 250);

  final PageController _pageController = PageController(viewportFraction: 0.98);
  int _currentPage = 0;
  bool _isCompleting = false;

  late final AnimationController _entryCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward();

  late final Animation<double> _entryFade = CurvedAnimation(
    parent: _entryCtrl,
    curve: Curves.easeOut,
  );

  late final Animation<Offset> _entrySlide = Tween<Offset>(
    begin: const Offset(0, 0.04),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));

  late final AnimationController _ctaGlowCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  )..repeat(reverse: true);

  late final Animation<double> _ctaGlow = Tween<double>(
    begin: 0.0,
    end: 0.18,
  ).animate(CurvedAnimation(parent: _ctaGlowCtrl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _pageController.dispose();
    _entryCtrl.dispose();
    _ctaGlowCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  double get _pageValue {
    if (!_pageController.hasClients) return _currentPage.toDouble();
    return _pageController.page ?? _currentPage.toDouble();
  }

  String get _ctaLabel {
    if (_currentPage == 0) return 'Get Started';
    if (_currentPage == 1) return 'Next';
    return 'Continue';
  }

  Future<void> _goToPage(int index) async {
    if (index == _currentPage) return;
    await _pageController.animateToPage(
      index,
      duration: _kPageTransition,
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleContinue() async {
    if (_currentPage < 2) {
      await _goToPage(_currentPage + 1);
      return;
    }
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    try {
      await ref.read(authControllerProvider.notifier).completeOnboarding();
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Page content definitions
  // ---------------------------------------------------------------------------

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const _PageContent(
          title: 'Get Paid Faster.\nStay in Control.',
          subtitle:
              'Create invoices, track payments, and never miss a follow-up.',
          cards: [
            _CardData(
              Icons.receipt_long_rounded,
              'Invoices',
              'Create and send quickly',
            ),
            _CardData(
              Icons.notifications_active_rounded,
              'Reminders',
              'Automate follow-ups politely',
            ),
          ],
        );
      case 1:
        return const _PageContent(
          title: 'Everything You Need to Manage',
          subtitle: 'Built for teams who care about clarity and cashflow.',
          cards: [
            _CardData(
              Icons.receipt_rounded,
              'Invoice Tracking',
              'See pending and overdue status instantly',
            ),
            _CardData(
              Icons.message_outlined,
              'Smart Follow-up',
              'Send WhatsApp and SMS reminders in seconds',
            ),
            _CardData(
              Icons.analytics_outlined,
              'Monthly Overview',
              'Understand payment momentum at a glance',
            ),
          ],
        );
      default:
        return const _PageContent(
          title: 'Stay Organized.\nStay Professional.',
          subtitle: 'Your business, simplified. No missed payments. No chaos.',
          cards: [
            _CardData(
              Icons.auto_graph_rounded,
              'Dashboard',
              'All your numbers in one view',
            ),
            _CardData(
              Icons.schedule_rounded,
              'Auto Scheduling',
              'Set it and forget it',
            ),
            _CardData(
              Icons.shield_outlined,
              'Secure & Private',
              'Your data stays yours',
            ),
          ],
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Pagination dots
  // ---------------------------------------------------------------------------

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          GestureDetector(
            onTap: () => _goToPage(i),
            child: AnimatedContainer(
              duration: _kPageTransition,
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == _currentPage ? 20 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == _currentPage
                    ? AppColors.textPrimary
                    : AppColors.textSecondary.withValues(alpha: 0.40),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Fixed CTA with subtle breathing glow
  // ---------------------------------------------------------------------------

  Widget _buildFixedCta() {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 20,
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AnimatedBuilder(
              animation: _ctaGlow,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(
                          alpha: _ctaGlow.value,
                        ),
                        blurRadius: 24,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: PremiumPrimaryButton(
                label: _ctaLabel,
                isLoading: _isCompleting,
                onPressed: _isCompleting ? null : _handleContinue,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Layer 1-4: Galaxy background
          const Positioned.fill(child: _GalaxyBackground()),

          // Content area
          SafeArea(
            child: FadeTransition(
              opacity: _entryFade,
              child: SlideTransition(
                position: _entrySlide,
                child: Column(
                  children: [
                    // Paged content fills available space
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: 3,
                        onPageChanged: (index) {
                          if (_currentPage == index) return;
                          setState(() => _currentPage = index);
                        },
                        itemBuilder: (context, index) {
                          return AnimatedBuilder(
                            animation: _pageController,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: _buildPage(index),
                            ),
                            builder: (context, child) {
                              final delta = _pageValue - index;
                              final distance = delta.abs().clamp(0.0, 1.0);
                              final opacity = (1 - (0.15 * distance)).clamp(
                                0.85,
                                1.0,
                              );
                              return Opacity(
                                opacity: opacity,
                                child: Transform.translate(
                                  offset: Offset(-delta * 14, 0),
                                  child: child,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    // Dots — between content and CTA
                    Padding(
                      padding: const EdgeInsets.only(bottom: 96),
                      child: _buildDots(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Fixed CTA
          _buildFixedCta(),
        ],
      ),
    );
  }
}

// =============================================================================
// Card data model
// =============================================================================

class _CardData {
  const _CardData(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title;
  final String subtitle;
}

// =============================================================================
// Galaxy Background — REAL image + overlay + noise
// =============================================================================

class _GalaxyBackground extends StatelessWidget {
  const _GalaxyBackground();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1: solid base
          Container(color: const Color(0xFF0F1115)),

          // Layer 2: real galaxy image
          Image.asset(
            'assets/images/galaxy.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),

          // Layer 3: dark overlay — light enough to keep galaxy visible
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.40),
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.50),
                ],
              ),
            ),
          ),

          // Layer 4: noise texture
          Positioned.fill(
            child: Opacity(
              opacity: 0.03,
              child: Image.asset(
                'assets/noise.png',
                repeat: ImageRepeat.repeat,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Page Content — headline + subtitle + staggered cards, NO scroll
// =============================================================================

class _PageContent extends StatefulWidget {
  const _PageContent({
    required this.title,
    required this.subtitle,
    required this.cards,
  });

  final String title;
  final String subtitle;
  final List<_CardData> cards;

  @override
  State<_PageContent> createState() => _PageContentState();
}

class _PageContentState extends State<_PageContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _stagger(double begin, double end) {
    final t = ((_ctrl.value - begin) / (end - begin)).clamp(0.0, 1.0);
    return Curves.easeOut.transform(t);
  }

  Widget _fadeSlide(Widget child, double progress, {double y = 16}) {
    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, (1 - progress) * y),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardCount = widget.cards.length;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final titleP = _stagger(0.0, 0.45);
        final subtitleP = _stagger(0.08, 0.55);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Headline
            _fadeSlide(
              Text(
                widget.title,
                maxLines: 4,
                softWrap: true,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 48,
                  height: 1.06,
                  letterSpacing: -0.8,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              titleP,
            ),
            const SizedBox(height: 16),

            // Subtitle
            _fadeSlide(
              Text(
                widget.subtitle,
                maxLines: 3,
                softWrap: true,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                  fontSize: 16,
                ),
              ),
              subtitleP,
            ),
            const SizedBox(height: 24),

            // Spacer pushes cards toward center-bottom
            const Spacer(),

            // Staggered glass cards
            for (var i = 0; i < cardCount; i++) ...[
              Builder(
                builder: (context) {
                  final cardBegin = 0.15 + (i * 0.10);
                  final cardEnd = (cardBegin + 0.40).clamp(0.0, 1.0);
                  final cardP = _stagger(cardBegin, cardEnd);

                  return _fadeSlide(
                    Transform.scale(
                      scale: 0.98 + (0.02 * cardP),
                      child: _GlassCard(data: widget.cards[i]),
                    ),
                    cardP,
                    y: 20,
                  );
                },
              ),
              if (i < cardCount - 1) const SizedBox(height: 16),
            ],

            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

// =============================================================================
// Glass Card — frosted with golden border glow
// =============================================================================

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.data});

  final _CardData data;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.14),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.40),
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(data.icon, size: 20, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
