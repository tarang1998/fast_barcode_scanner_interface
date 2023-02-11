import 'dart:async';

import 'package:fast_barcode_scanner_platform_interface/src/types/image_source.dart';
import 'package:flutter/services.dart';

import 'fast_barcode_scanner_platform_interface.dart';
import 'types/barcode.dart';
import 'types/barcode_type.dart';
import 'types/preview_configuration.dart';

class MethodChannelFastBarcodeScanner extends FastBarcodeScannerPlatform {
  static const MethodChannel _channel =
      MethodChannel('com.jhoogstraat/fast_barcode_scanner');
  static const EventChannel _detectionEvents =
      EventChannel('com.jhoogstraat/fast_barcode_scanner/detections');

  final Stream<dynamic> _detectionEventStream =
      _detectionEvents.receiveBroadcastStream();
  StreamSubscription<dynamic>? _barcodeEventStreamSubscription;
  OnDetectionHandler? _onDetectHandler;

  @override
  Future<PreviewConfiguration> init(
    List<BarcodeType> types,
    Resolution resolution,
    Framerate framerate,
    DetectionMode detectionMode,
    CameraPosition position, {
    IOSApiMode? apiMode,
  }) async {
    final response = await _channel.invokeMethod('init', {
      'types': types.map((e) => e.name).toList(growable: false),
      'mode': detectionMode.name,
      'res': resolution.name,
      'fps': framerate.name,
      'pos': position.name,
      ...apiMode?.configMap ?? {},
    });
    return PreviewConfiguration(response);
  }

  @override
  void setOnDetectHandler(OnDetectionHandler handler) async {
    _onDetectHandler = handler;
    _barcodeEventStreamSubscription ??=
        _detectionEventStream.listen(_handlePlatformBarcodeEvent);
  }

  @override
  Future<void> start() => _channel.invokeMethod('start');

  @override
  Future<void> stop() => _channel.invokeMethod('stop');

  @override
  Future<void> startDetector() => _channel.invokeMethod('startDetector');

  @override
  Future<void> stopDetector() => _channel.invokeMethod('stopDetector');

  @override
  Future<void> dispose() async {
    await _barcodeEventStreamSubscription?.cancel();
    _barcodeEventStreamSubscription = null;
    _onDetectHandler = null;
    return _channel.invokeMethod('dispose');
  }

  @override
  Future<bool> toggleTorch() =>
      _channel.invokeMethod('torch').then<bool>((isOn) => isOn);

  @override
  Future<PreviewConfiguration> changeConfiguration({
    List<BarcodeType>? types,
    Resolution? resolution,
    Framerate? framerate,
    DetectionMode? detectionMode,
    CameraPosition? position,
  }) async {
    final response = await _channel.invokeMethod('config', {
      if (types != null) 'types': types.map((e) => e.name).toList(),
      if (detectionMode != null) 'mode': detectionMode.name,
      if (resolution != null) 'res': resolution.name,
      if (framerate != null) 'fps': framerate.name,
      if (position != null) 'pos': position.name,
    });
    return PreviewConfiguration(response);
  }

  @override
  Future<List<Barcode>?> scanImage(ImageSource source) async {
    final List<Object?>? response = await _channel.invokeMethod(
      'scan',
      source.data,
    );

    return response?.map((e) => Barcode(e as List<dynamic>)).toList();
  }

  void _handlePlatformBarcodeEvent(dynamic data) {
    // This might fail if the code type is not present in the list of available code types.
    // Barcode init will throw in this case. Ignore this cases and continue as if nothing happened.
    try {
      final barcodes = (data as List<dynamic>).map((e) => Barcode(e)).toList();
      _onDetectHandler?.call(barcodes);
      // ignore: empty_catches
    } catch (e) {}
  }
}
