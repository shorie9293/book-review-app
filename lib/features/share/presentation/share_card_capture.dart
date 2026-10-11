/// シェアカード画像キャプチャ抽象と RepaintBoundary 実装。
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// カード画像キャプチャの抽象（テストでフェイク注入可能にする）。
abstract class ShareCardCapture {
  Future<Uint8List?> capture(GlobalKey boundaryKey);
}

/// RepaintBoundary から PNG バイト列を生成する実装。
class RepaintBoundaryCapture implements ShareCardCapture {
  const RepaintBoundaryCapture();

  @override
  Future<Uint8List?> capture(GlobalKey boundaryKey) async {
    final boundary = boundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || !boundary.attached) {
      return null;
    }
    try {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}
