import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Liquid-glass building blocks.
///
/// Glass = translucent layered surface + thin bright edge + soft shadow. A real backdrop blur is expensive on
/// low-end phones, so [GlassSurface] only blurs when asked (`blur: true`) and the app uses that for a handful of
/// small floating layers (navigation bar, sheets, dialogs, hero card). Everything else is a cheap translucent
/// gradient. Blur is skipped automatically when the user asks for high contrast, or when
/// [GlassConfig.blurEnabled] is switched off, and the fill becomes more opaque so text stays readable.
class GlassConfig {
  static bool blurEnabled = true;
  static const double blurSigma = 16;
}

/// Soft aurora behind every page: a cool light base with two faint teal / periwinkle glows.
/// Static (no animation) so it costs one cheap paint per page.
class GlassBackground extends StatelessWidget {
  final Widget? child;
  const GlassBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF4F8FC), Color(0xFFE9F0F8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -140,
              right: -120,
              child: _glow(AppColors.primaryLight.withValues(alpha: 0.20), 360),
            ),
            Positioned(
              bottom: -160,
              left: -140,
              child: _glow(AppColors.accentLight.withValues(alpha: 0.20), 400),
            ),
            ?child,
          ],
        ),
      ),
    );
  }

  static Widget _glow(Color c, double size) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)]),
      ),
    ),
  );
}

/// Page transition: the glass background is drawn with every page (so pages never ghost through each other),
/// and the page itself fades and rises slightly. Zero duration when the user removes animations.
class GlassPageTransitionsBuilder extends PageTransitionsBuilder {
  const GlassPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final page = GlassBackground(child: child);
    if (route.isFirst || MediaQuery.maybeDisableAnimationsOf(context) == true)
      return page;
    final curved = CurvedAnimation(parent: animation, curve: AppMotion.curve);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: page,
      ),
    );
  }
}

enum GlassTone { normal, strong, tinted }

/// A glass panel. Use it for the few things that should feel like layered glass; keep the rest simple.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool blur;
  final GlassTone tone;
  final Color? tint;
  final bool shadow;
  final BorderRadiusGeometry? borderRadius;

  const GlassSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = AppRadius.lg,
    this.blur = false,
    this.tone = GlassTone.normal,
    this.tint,
    this.shadow = true,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    final useBlur = blur && GlassConfig.blurEnabled && !highContrast;
    final r = borderRadius ?? BorderRadius.circular(radius);

    // Fill: a light top-left sheen over the translucent base. More opaque when we are not blurring.
    final double a = switch (tone) {
      GlassTone.strong => 0.92,
      GlassTone.tinted => 0.80,
      GlassTone.normal => useBlur ? 0.62 : 0.78,
    };
    // A tint is a pale wash over white glass, never a saturated block (keeps text contrast high).
    final base = tint == null
        ? Colors.white
        : Color.alphaBlend(tint!.withValues(alpha: 0.16), Colors.white);
    final fill = LinearGradient(
      colors: [
        base.withValues(alpha: (a + 0.10).clamp(0.0, 1.0)),
        base.withValues(alpha: (a - 0.06).clamp(0.0, 1.0)),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final panel = DecoratedBox(
      decoration: BoxDecoration(
        gradient: fill,
        borderRadius: r,
        border: Border.all(color: AppColors.glassEdge, width: 1),
      ),
      child: Padding(padding: padding, child: child),
    );

    Widget result = useBlur
        ? ClipRRect(
            borderRadius: r,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: GlassConfig.blurSigma,
                sigmaY: GlassConfig.blurSigma,
              ),
              child: panel,
            ),
          )
        : ClipRRect(borderRadius: r, child: panel);

    if (shadow) {
      // The shadow is painted OUTSIDE the panel only: under a translucent surface a normal box-shadow
      // would show through and muddy the glass.
      result = CustomPaint(painter: _OuterShadowPainter(r), child: result);
    }
    return result;
  }
}

class _OuterShadowPainter extends CustomPainter {
  final BorderRadiusGeometry radius;
  const _OuterShadowPainter(this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = radius.resolve(TextDirection.ltr).toRRect(Offset.zero & size);
    final outside = Path.combine(
      PathOperation.difference,
      Path()
        ..addRect(Rect.fromLTWH(-60, -60, size.width + 120, size.height + 140)),
      Path()..addRRect(rrect),
    );
    canvas.save();
    canvas.clipPath(outside);
    canvas.drawRRect(
      rrect.shift(const Offset(0, 8)),
      Paint()
        ..color = AppColors.glassShadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OuterShadowPainter old) => old.radius != radius;
}

/// A tappable (optional) glass card with a proper 48 dp minimum target, ripple and semantics.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final bool blur;
  final GlassTone tone;
  final Color? tint;
  final String? semanticLabel;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.radius = AppRadius.lg,
    this.blur = false,
    this.tone = GlassTone.normal,
    this.tint,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final surface = GlassSurface(
      radius: radius,
      blur: blur,
      tone: tone,
      tint: tint,
      padding: EdgeInsets.zero,
      child: _inner(),
    );
    if (semanticLabel != null)
      return Semantics(container: true, label: semanticLabel, child: surface);
    return surface;
  }

  Widget _inner() {
    final content = Padding(padding: padding, child: child);
    if (onTap == null) return content;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.touch),
          child: content,
        ),
      ),
    );
  }
}

class GlassNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const GlassNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Floating bottom navigation: a blurred glass pill with an animated selection indicator.
class GlassNavigationBar extends StatelessWidget {
  final List<GlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const GlassNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  static const double height = 68;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        bottom > 0 ? bottom : AppSpacing.sm + 4,
      ),
      child: GlassSurface(
        blur: true,
        radius: 30,
        tone: GlassTone.normal,
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          height: height - 12,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final GlassNavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: AppMotion.of(context),
          curve: AppMotion.curve,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: selected
                ? Border.all(color: AppColors.primary.withValues(alpha: 0.22))
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                size: 22,
                color: color,
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: AppText.family,
                      fontSize: 10.5,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal bottom sheet in glass. Handles the keyboard and the system insets.
Future<T?> showGlassSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.midnight.withValues(alpha: 0.38),
    builder: (ctx) => GlassSurface(
      blur: true,
      tone: GlassTone.strong,
      shadow: false,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.xl),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Builder(builder: builder),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Dialog in glass: rounded, blurred, scroll-safe.
class GlassDialog extends StatelessWidget {
  final String title;
  final Widget? icon;
  final Widget content;
  final List<Widget> actions;

  const GlassDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: GlassSurface(
        blur: true,
        tone: GlassTone.strong,
        radius: AppRadius.xl,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[icon!, const SizedBox(width: 10)],
                    Expanded(child: Text(title, style: AppText.title)),
                  ],
                ),
                const SizedBox(height: 12),
                DefaultTextStyle(style: AppText.bodySecondary, child: content),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: actions,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> showGlassDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showDialog<T>(
  context: context,
  barrierColor: AppColors.midnight.withValues(alpha: 0.42),
  builder: builder,
);

enum StatusTone { brand, success, warning, error, info, neutral }

/// Consistent status chip. Text colours are chosen to keep >= 4.5:1 contrast on their tinted fill.
class StatusChip extends StatelessWidget {
  final String label;
  final StatusTone tone;
  final IconData? icon;
  final bool dense;

  const StatusChip({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
    this.dense = false,
  });

  static const Map<StatusTone, (Color fill, Color text)> palette = {
    StatusTone.brand: (AppColors.primary, Color(0xFF0A5F68)),
    StatusTone.success: (AppColors.success, Color(0xFF0A6045)),
    StatusTone.warning: (AppColors.warning, Color(0xFF7A4B00)),
    StatusTone.error: (AppColors.error, Color(0xFF9E1C27)),
    StatusTone.info: (AppColors.info, Color(0xFF0B5486)),
    StatusTone.neutral: (Color(0xFF56667F), Color(0xFF3A475E)),
  };

  @override
  Widget build(BuildContext context) {
    final (fill, text) = palette[tone]!;
    return Semantics(
      label: label,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 8 : 10,
          vertical: dense ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: fill.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: fill.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: dense ? 12 : 14, color: text),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppText.family,
                  color: text,
                  fontSize: dense ? 10.5 : 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section title with optional caption and trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? caption;
  final Widget? trailing;
  const SectionHeader({
    super.key,
    required this.title,
    this.caption,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.heading),
                if (caption != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(caption!, style: AppText.meta),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Centres content in a readable column on tablets/landscape while using the full width on phones.
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ResponsiveBody({super.key, required this.child, this.maxWidth = 720});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Friendly empty state (no data yet), consistent across screens.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: AppText.heading),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.bodySecondary,
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
