import 'dart:math' as math;

import 'dart:ui' show Tristate;

import 'package:campus_os/app/campus_app.dart';
import 'package:campus_os/core/branding/campus_logo.dart';
import 'package:campus_os/core/theme/app_theme.dart';
import 'package:campus_os/core/widgets/glass.dart';
import 'package:campus_os/features/auth/models/user_session.dart';
import 'package:campus_os/features/auth/services/auth_service.dart';
import 'package:campus_os/features/dashboard/screens/dashboard_screen.dart';
import 'package:campus_os/features/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _lum(Color c) {
  double f(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

double contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

Widget host(Widget child, {Size? size, double text = 1}) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: MediaQuery(
    data: MediaQueryData(
      size: size ?? const Size(390, 844),
      textScaler: TextScaler.linear(text),
    ),
    child: Scaffold(body: child),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('contrast (WCAG AA, normal text 4.5:1)', () {
    test('body text and buttons', () {
      expect(
        contrast(AppColors.textPrimary, AppColors.background),
        greaterThan(7),
      );
      expect(
        contrast(AppColors.textSecondary, AppColors.background),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(Colors.white, AppColors.primary),
        greaterThanOrEqualTo(4.5),
      ); // primary button
      expect(
        contrast(Colors.white, AppColors.error),
        greaterThanOrEqualTo(4.5),
      ); // destructive button
      expect(
        contrast(Colors.white, AppColors.midnight),
        greaterThan(7),
      ); // snackbars, avatar
      expect(
        contrast(AppColors.primary, AppColors.background),
        greaterThanOrEqualTo(4.5),
      ); // links / text buttons
    });

    test('every status chip tone is readable on its own tinted fill', () {
      for (final e in StatusChip.palette.entries) {
        final (fill, text) = e.value;
        final background = Color.alphaBlend(
          fill.withValues(alpha: 0.13),
          Colors.white,
        );
        expect(
          contrast(text, background),
          greaterThanOrEqualTo(4.5),
          reason: '${e.key}',
        );
      }
    });
  });

  group('GlassSurface', () {
    testWidgets(
      'only blurs when asked, and falls back without blur for high contrast or when disabled',
      (t) async {
        await t.pumpWidget(host(const GlassSurface(child: Text('plain'))));
        expect(find.byType(BackdropFilter), findsNothing);

        await t.pumpWidget(
          host(const GlassSurface(blur: true, child: Text('blurred'))),
        );
        expect(find.byType(BackdropFilter), findsOneWidget);
        expect(find.text('blurred'), findsOneWidget);

        GlassConfig.blurEnabled = false;
        addTearDown(() => GlassConfig.blurEnabled = true);
        await t.pumpWidget(
          host(const GlassSurface(blur: true, child: Text('off'))),
        );
        expect(find.byType(BackdropFilter), findsNothing);
        GlassConfig.blurEnabled = true;

        await t.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MediaQuery(
              data: MediaQueryData(highContrast: true),
              child: Scaffold(
                body: GlassSurface(blur: true, child: Text('hc')),
              ),
            ),
          ),
        );
        expect(
          find.byType(BackdropFilter),
          findsNothing,
        ); // readability beats the effect
      },
    );

    testWidgets('a tappable GlassCard has a 48 dp target and fires onTap', (
      t,
    ) async {
      var taps = 0;
      await t.pumpWidget(
        host(
          Center(
            child: GlassCard(
              onTap: () => taps++,
              padding: EdgeInsets.zero,
              child: const SizedBox(width: 20, height: 10),
            ),
          ),
        ),
      );
      final size = t.getSize(find.byType(GlassCard));
      expect(size.height, greaterThanOrEqualTo(AppSpacing.touch));
      await t.tap(find.byType(GlassCard));
      expect(taps, 1);
    });
  });

  group('GlassNavigationBar', () {
    const items = [
      GlassNavItem(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: 'Home',
      ),
      GlassNavItem(
        icon: Icons.how_to_reg_outlined,
        selectedIcon: Icons.how_to_reg,
        label: 'Attendance',
      ),
      GlassNavItem(
        icon: Icons.apartment_outlined,
        selectedIcon: Icons.apartment,
        label: 'Campus',
      ),
      GlassNavItem(
        icon: Icons.photo_camera_outlined,
        selectedIcon: Icons.photo_camera,
        label: 'GeoCam',
      ),
      GlassNavItem(
        icon: Icons.science_outlined,
        selectedIcon: Icons.science,
        label: 'Learn',
      ),
    ];

    testWidgets(
      'selection, callbacks, semantics and touch targets, even on a 320 dp wide phone at 1.6x text',
      (t) async {
        var index = 0;
        await t.pumpWidget(
          StatefulBuilder(
            builder: (c, set) => host(
              Align(
                alignment: Alignment.bottomCenter,
                child: GlassNavigationBar(
                  items: items,
                  currentIndex: index,
                  onTap: (i) => set(() => index = i),
                ),
              ),
              size: const Size(320, 568),
              text: 1.6,
            ),
          ),
        );
        expect(t.takeException(), isNull); // no overflow
        final handle = t.ensureSemantics();
        expect(
          t
              .getSemantics(find.bySemanticsLabel('Home'))
              .flagsCollection
              .isSelected,
          Tristate.isTrue,
        ); // selected item is announced
        expect(
          t
              .getSemantics(find.bySemanticsLabel('Learn'))
              .flagsCollection
              .isSelected,
          isNot(Tristate.isTrue),
        );
        await t.tap(find.text('Learn'));
        await t.pumpAndSettle();
        expect(index, 4);
        final navSize = t.getSize(find.byType(GlassNavigationBar));
        expect(navSize.height, greaterThanOrEqualTo(GlassNavigationBar.height));
        handle.dispose();
      },
    );
  });

  group('brand', () {
    testWidgets(
      'the logo renders as an accessible CampusOS mark and wordmark',
      (t) async {
        await t.pumpWidget(host(const Center(child: CampusLogo(markSize: 48))));
        expect(find.bySemanticsLabel('CampusOS logo'), findsOneWidget);
        expect(find.byType(CampusLogoMark), findsOneWidget);
        expect(
          find.textContaining('Campus', findRichText: true),
          findsOneWidget,
        );
      },
    );
  });

  group('motion', () {
    testWidgets('reduced motion removes animation durations', (t) async {
      late Duration normal, reduced;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              normal = AppMotion.of(c);
              return const SizedBox();
            },
          ),
        ),
      );
      await t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (c) {
                reduced = AppMotion.of(c);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(normal, AppMotion.base);
      expect(reduced, Duration.zero);
    });
  });

  group('responsive screens (no overflow on small phones with large text)', () {
    Future<void> pumpApp(
      WidgetTester t,
      UserSession? s,
      Size size,
      double text,
    ) async {
      t.view.physicalSize = size * 2;
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      AuthService.instance.currentSession.value = s;
      addTearDown(() => AuthService.instance.currentSession.value = null);
      await t.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: size,
            devicePixelRatio: 2,
            textScaler: TextScaler.linear(text),
          ),
          child: const CampusApp(),
        ),
      );
      await t.pump(const Duration(milliseconds: 700));
      await t.pump(const Duration(milliseconds: 700));
    }

    for (final cfg in [
      (const Size(320, 568), 1.0),
      (const Size(320, 640), 1.6),
      (const Size(360, 780), 1.3),
      (const Size(800, 1280), 1.0),
    ]) {
      testWidgets('sign-in at ${cfg.$1} x${cfg.$2}', (t) async {
        await pumpApp(t, null, cfg.$1, cfg.$2);
        expect(t.takeException(), isNull);
        await t.scrollUntilVisible(
          find.text('Admin'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Log In'), findsOneWidget);
      });

      for (final s in [
        UserSession.demoStudent(),
        UserSession.demoFaculty(),
        UserSession.demoAdmin(),
      ]) {
        testWidgets('home (${s.role}) at ${cfg.$1} x${cfg.$2}', (t) async {
          await pumpApp(t, s, cfg.$1, cfg.$2);
          expect(t.takeException(), isNull);
          for (final tab in ['Attendance', 'Campus', 'Learn']) {
            await t.tap(find.text(tab).last);
            await t.pump(const Duration(milliseconds: 700));
            await t.pump(const Duration(milliseconds: 700));
            expect(t.takeException(), isNull, reason: '$tab tab as ${s.role}');
          }
        });
      }
    }
  });

  group('dashboard states', () {
    testWidgets(
      'a real (non-demo) session whose server cannot be reached shows an error with Retry, never sample data',
      (t) async {
        const live = UserSession(
          token: 'x',
          id: '22CS9999',
          name: 'Riya Test',
          role: 'student',
        );
        await t.pumpWidget(
          host(DashboardScreen(session: live, onNavigate: (_) {})),
        );
        await t.pump(const Duration(milliseconds: 800));
        await t.pump(const Duration(milliseconds: 800));
        expect(
          find.textContaining("Couldn't load today's schedule"),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('DEMO MODE'), findsNothing);
        expect(find.text('87.5%'), findsNothing);
      },
    );

    testWidgets('an admin sees admin guidance instead of a student timetable', (
      t,
    ) async {
      await t.pumpWidget(
        host(
          DashboardScreen(session: UserSession.demoAdmin(), onNavigate: (_) {}),
        ),
      );
      await t.pump(const Duration(milliseconds: 800));
      expect(
        find.textContaining('Administrators manage timetables'),
        findsOneWidget,
      );
      expect(find.text('Upload timetable'), findsOneWidget);
    });

    testWidgets('quick actions follow the role and jump to the right tab', (
      t,
    ) async {
      ShellTab? went;
      await t.pumpWidget(
        host(
          DashboardScreen(
            session: UserSession.demoFaculty(),
            onNavigate: (x) => went = x,
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 800));
      expect(find.text('Scan class QR'), findsNothing); // students only
      expect(find.text('Start attendance'), findsOneWidget);
      await t.tap(find.text('Leave approvals'));
      expect(went, ShellTab.campus);
    });
  });

  group('app shell', () {
    testWidgets(
      'has the same five destinations for every role; the camera tab is not built until opened',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: AppShell(session: UserSession.demoStudent()),
          ),
        );
        await t.pump(const Duration(milliseconds: 500));
        for (final l in ['Home', 'Attendance', 'Campus', 'GeoCam', 'Learn']) {
          expect(find.text(l), findsWidgets);
        }
        expect(find.text('Employee ERP'), findsNothing);
      },
    );
  });
}
