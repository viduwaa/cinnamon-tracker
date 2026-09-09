/// Google Maps SDK key, injected at build time from `env.json` via
/// `--dart-define-from-file` (VS Code launch config does this automatically;
/// see app/README.md).
///
/// Same pattern as `API_BASE_URL` in api_client.dart: build-time injection,
/// never committed. The Android side also receives the key through a
/// manifestPlaceholder decoded from the same dart-define
/// (android/app/build.gradle.kts).
const String mapsApiKey = String.fromEnvironment("MAPS_API_KEY");

/// Whether the map picker can render at all. Without a compiled-in key the
/// wizard degrades to an informational card and the farm is saved without
/// coordinates (the column is nullable).
final bool kMapsEnabled = mapsApiKey.isNotEmpty;
