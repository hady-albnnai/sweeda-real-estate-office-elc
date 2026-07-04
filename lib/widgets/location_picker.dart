import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../core/theme/app_theme.dart';

/// مكوّن اختيار موقع على خريطة (OpenStreetMap — مجاني بدون API key)
/// يستخدم في add_offer_screen و edit_offer_screen
class LocationPicker extends StatefulWidget {
  final LatLng? initial;
  final void Function(LatLng location) onPicked;
  final double height;

  const LocationPicker({
    super.key,
    this.initial,
    required this.onPicked,
    this.height = 300,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  late LatLng _picked;
  final _mapController = MapController();
  bool _locating = false;

  // الموقع الافتراضي: مركز السويداء، سوريا
  static const LatLng _sweedaCenter = LatLng(32.7094, 36.5694);

  @override
  void initState() {
    super.initState();
    _picked = widget.initial ?? _sweedaCenter;
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      // طلب الإذن
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _snack('تم رفض إذن الموقع');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final newLoc = LatLng(position.latitude, position.longitude);
      setState(() => _picked = newLoc);
      _mapController.move(newLoc, 15);
      widget.onPicked(newLoc);
    } catch (e) {
      _snack('فشل تحديد الموقع: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    AppTheme.showSnackBar(context, SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.4)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _picked,
                initialZoom: 13,
                onTap: (_, latLng) {
                  setState(() => _picked = latLng);
                  widget.onPicked(latLng);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.sweeda.realestate',
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: _picked,
                    width: 50,
                    height: 50,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 50,
                    ),
                  ),
                ]),
              ],
            ),
            // أزرار التحكم
            Positioned(
              top: 8,
              right: 8,
              child: Column(children: [
                FloatingActionButton.small(
                  heroTag: 'loc',
                  backgroundColor: AppTheme.primaryGold,
                  foregroundColor: Colors.black,
                  onPressed: _locating ? null : _useMyLocation,
                  child: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.my_location),
                ),
                const SizedBox(height: 6),
                FloatingActionButton.small(
                  heroTag: 'zoomin',
                  backgroundColor: AppTheme.surfaceBlack,
                  foregroundColor: AppTheme.primaryGold,
                  onPressed: () => _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1),
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 6),
                FloatingActionButton.small(
                  heroTag: 'zoomout',
                  backgroundColor: AppTheme.surfaceBlack,
                  foregroundColor: AppTheme.primaryGold,
                  onPressed: () => _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1),
                  child: const Icon(Icons.remove),
                ),
              ]),
            ),
            // الإحداثيات بأسفل
            Positioned(
              bottom: 8,
              left: 8,
              right: 70,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '📍 ${_picked.latitude.toStringAsFixed(5)}, ${_picked.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// عارض موقع للقراءة فقط (يستخدم في offer_detail_screen)
class LocationViewer extends StatelessWidget {
  final double lat;
  final double lng;
  final double height;

  const LocationViewer({
    super.key,
    required this.lat,
    required this.lng,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final point = LatLng(lat, lng);
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: point,
            initialZoom: 15,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.sweeda.realestate',
            ),
            MarkerLayer(markers: [
              Marker(
                point: point,
                width: 50,
                height: 50,
                child: const Icon(Icons.location_on,
                    color: Colors.red, size: 50),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
