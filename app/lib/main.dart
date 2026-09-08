import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "app/router.dart";
import "app/theme.dart";
import "core/sync/sync_worker.dart";

void main() {
  runApp(const ProviderScope(child: CinnamonTraceApp()));
}

class CinnamonTraceApp extends ConsumerWidget {
  const CinnamonTraceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Activate the sync triggers (app start drain, connectivity regained,
    // after re-login) for the lifetime of the app.
    ref.watch(syncBootstrapProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: "Cinnamon Trace",
      debugShowCheckedModeBanner: false,
      theme: Ct.theme(),
      routerConfig: router,
    );
  }
}
