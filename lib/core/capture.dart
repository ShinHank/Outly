import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Renders a RepaintBoundary to PNG bytes at a fixed pixel width, so exports
/// look the same on every device.
Future<Uint8List?> capturePng(GlobalKey key, {required double width}) async {
  final boundary =
      key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  await WidgetsBinding.instance.endOfFrame;
  final ratio = width / boundary.size.width;
  final image = await boundary.toImage(pixelRatio: ratio);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data?.buffer.asUint8List();
}
