import 'package:flutter/material.dart';

import '../config/pos_app_info.dart';
import '../theme/pos_theme.dart';

/// Full-screen boot UI while the app restores server + session.
///
/// Brand logos ship on a black plate (`app_logo.png` / `app_emblem.png`), so
/// this screen uses a matching black canvas — not the light app canvas.
class PosBootstrapScreen extends StatelessWidget {
  const PosBootstrapScreen({super.key, this.accent});

  final Color? accent;

  static const _canvas = Color(0xFF000000);

  @override
  Widget build(BuildContext context) {
    final brand = accent ?? PosTheme.defaultAccent;
    final logoSize = (MediaQuery.sizeOf(context).shortestSide * 0.65)
        .clamp(120.0, 280.0);

    return Scaffold(
      backgroundColor: _canvas,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(_canvas, brand, 0.14)!,
              _canvas,
              _canvas,
            ],
            stops: const [0, 0.45, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    PosAppInfo.logoAsset,
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    semanticLabel: PosAppInfo.displayName,

                  ),
                  const SizedBox(height: 36),
                  Text(
                    'Connecting…',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      color: brand,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
