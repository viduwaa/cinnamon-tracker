import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart";
import "package:geolocator/geolocator.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "../../app/theme.dart";

/// Default map center: Matale, a representative central cinnamon district.
const _initialTarget = LatLng(7.57, 80.62);

/// Map-based farm location picker.
///
/// Tap to drop a pin, drag the pin to fine-tune, "My location" grabs a GPS
/// fix, the chip's ✕ clears. Selection is optional — the wizard persists
/// lat/lng only when a pin is set.
class FarmLocationPicker extends StatefulWidget {
  const FarmLocationPicker({
    super.key,
    required this.lat,
    required this.lng,
    required this.onChanged,
  });

  final double? lat;
  final double? lng;
  final ValueChanged<(double?, double?)> onChanged;

  @override
  State<FarmLocationPicker> createState() => _FarmLocationPickerState();
}

class _FarmLocationPickerState extends State<FarmLocationPicker> {
  GoogleMapController? _map;
  LatLng? _pin;
  bool _locating = false;
  bool _showMyLocation = false;
  LatLng? _pendingCameraTarget;

  @override
  void initState() {
    super.initState();
    _pin = (widget.lat != null && widget.lng != null)
        ? LatLng(widget.lat!, widget.lng!)
        : null;
    if (_pin == null) _centerOnDeviceLocation();
  }

  /// If location permission is already granted, center the map on the device
  /// and show the live blue my-location dot — the farmer just taps near it.
  /// Permission is never requested on open; "My location" asks explicitly.
  Future<void> _centerOnDeviceLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.best),
      );
      if (!mounted) return;
      final target = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _showMyLocation = true;
        _pendingCameraTarget = target;
      });
      await _map
          ?.moveCamera(CameraUpdate.newLatLngZoom(target, 15));
    } catch (_) {
      // Location is optional here — the map stays on the default view.
    }
  }

  @override
  void didUpdateWidget(covariant FarmLocationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lat != oldWidget.lat || widget.lng != oldWidget.lng) {
      _pin = (widget.lat != null && widget.lng != null)
          ? LatLng(widget.lat!, widget.lng!)
          : null;
    }
    if (oldWidget.lat == null &&
        oldWidget.lng == null &&
        widget.lat != null &&
        widget.lng != null &&
        _map != null) {
      _map!
          .moveCamera(CameraUpdate.newLatLng(LatLng(widget.lat!, widget.lng!)));
    }
  }

  void _setPin(LatLng target) {
    setState(() => _pin = target);
    widget.onChanged((target.latitude, target.longitude));
  }

  Future<void> _useMyLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
    });
    try {
      bool serviceOn = await Geolocator.isLocationServiceEnabled();
      if (serviceOn) {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text("Location permission needed to use GPS")),
            );
          }
          return;
        }
        final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.best),
        );
        final target = LatLng(pos.latitude, pos.longitude);
        _setPin(target);
        await _map?.moveCamera(CameraUpdate.newLatLngZoom(target, 16));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Please turn on location services")),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't get your location")),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _clear() {
    setState(() => _pin = null);
    widget.onChanged((null, null));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Location (optional)", style: text.labelMedium),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(Ct.radius),
          child: SizedBox(
            height: 240,
            width: double.infinity,
            child: Stack(
              children: [
                GoogleMap(
                  // The wizard is a scrollable form; without eager gesture
                  // recognition the parent scroll steals map drags and the
                  // platform view never gets pinch-to-zoom. The map owns ALL
                  // gestures inside its bounds (scroll the form elsewhere).
                  gestureRecognizers: {
                    Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer()),
                  },
                  initialCameraPosition: CameraPosition(
                    target: _pin ?? _pendingCameraTarget ?? _initialTarget,
                    zoom: (_pin != null || _pendingCameraTarget != null) ? 15 : 7,
                  ),
                  onMapCreated: (c) {
                    _map = c;
                    // Camera fix may have arrived before the map finished
                    // creating — apply it now.
                    final t = _pendingCameraTarget;
                    if (t != null) {
                      c.moveCamera(CameraUpdate.newLatLngZoom(t, 15));
                    }
                  },
                  onTap: _setPin,
                  markers: _pin == null
                      ? const <Marker>{}
                      : {
                          Marker(
                            markerId: const MarkerId("farm"),
                            position: _pin!,
                            draggable: true,
                            onDragEnd: (p) => _setPin(p),
                          ),
                        },
                  myLocationEnabled: _showMyLocation,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),
                // Right-side map controls: my-location + zoom, compact chips
                // so the map stays one-tap operable without pinch gestures.
                Positioned(
                  right: 10,
                  top: 10,
                  child: Column(
                    children: [
                      _MapChip(
                        icon: Icons.my_location,
                        label: "My location",
                        onTap: _locating ? null : _useMyLocation,
                        child: _locating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.2, color: Ct.cinnamon),
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      _MapChip(
                        icon: Icons.add,
                        tooltip: "Zoom in",
                        onTap: () =>
                            _map?.moveCamera(CameraUpdate.zoomIn()),
                      ),
                      const SizedBox(height: 4),
                      _MapChip(
                        icon: Icons.remove,
                        tooltip: "Zoom out",
                        onTap: () =>
                            _map?.moveCamera(CameraUpdate.zoomOut()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.location_on_outlined,
                size: 16, color: Ct.faded),
            const SizedBox(width: 6),
            Expanded(
              child: _pin == null
                  ? Text(
                      "Tap the map to drop a pin",
                      style: text.bodyMedium?.copyWith(color: Ct.faded),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : Text(
                      "Lat ${_pin!.latitude.toStringAsFixed(6)}, "
                      "Lng ${_pin!.longitude.toStringAsFixed(6)}",
                      style: text.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            IconButton(
              tooltip: "Clear location",
              icon: const Icon(Icons.close, size: 20),
              color: Ct.faded,
              onPressed: _pin == null ? null : _clear,
            ),
          ],
        ),
      ],
    );
  }
}

/// Compact pill chip overlaid on the map (my-location / zoom buttons).
class _MapChip extends StatelessWidget {
  const _MapChip({
    required this.icon,
    required this.onTap,
    this.label,
    this.tooltip,
    this.child,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? label;
  final String? tooltip;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Ct.paper.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: label != null ? 12.0 : 10.0, vertical: 8),
          child: child ??
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: Ct.cinnamon),
                  if (label != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      label!,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: Ct.cinnamon),
                    ),
                  ],
                ],
              ),
        ),
      ),
    );
  }
}
