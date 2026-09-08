import "package:flutter/material.dart";

import "../../app/theme.dart";

/// Shown while the persisted session is restored from secure storage +
/// MetaKv on app boot. The router redirects here until auth finishes
/// restoring, so no auth-gated screen flashes before the decision.
class BootScreen extends StatelessWidget {
  const BootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Ct.cinnamon,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.spa_outlined, color: Ct.cream, size: 36),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Ct.cinnamon),
          ],
        ),
      ),
    );
  }
}
