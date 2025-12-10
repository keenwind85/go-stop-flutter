import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../config/constants.dart';

class TurnOverlay extends PositionComponent with HasGameRef {
  final Vector2 screenSize;
  late RectangleComponent _background;
  late TextComponent _text;

  TurnOverlay(this.screenSize) : super(priority: 100); // High priority to be on top

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Semi-transparent background covering the bottom area (hand area)
    // Assuming hand area is roughly the bottom 200 pixels
    final overlayHeight = 220.0;
    position = Vector2(0, screenSize.y - overlayHeight);
    size = Vector2(screenSize.x, overlayHeight);

    _background = RectangleComponent(
      size: size,
      paint: Paint()..color = Colors.black.withOpacity(0.5),
    );

    _text = TextComponent(
      text: '상대 턴입니다',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      anchor: Anchor.center,
      position: size / 2,
    );

    add(_background);
    add(_text);
    
    // Initially hidden
    isVisible = false;
  }

  set isVisible(bool visible) {
    if (visible) {
      if (parent == null) {
        gameRef.add(this);
      }
    } else {
      if (parent != null) {
        removeFromParent();
      }
    }
  }
}
