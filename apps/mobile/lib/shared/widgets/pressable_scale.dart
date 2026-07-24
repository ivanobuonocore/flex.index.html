import 'package:flutter/material.dart';
import 'package:pip_design_system/pip_design_system.dart';

/// Piccola risposta fisica al tocco, pensata per card e pillole interattive.
/// Non altera colori o contenuti: rende solo più chiaro che l'elemento è
/// stato premuto, sia su mobile sia sul web.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = AppMotion.pressedScale,
    this.hoverScale = AppMotion.hoverScale,
    this.hoverLift = AppMotion.cardHoverLift,
  });

  final Widget child;
  final bool enabled;
  final double pressedScale;
  final double hoverScale;
  final double hoverLift;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;
  bool _hovered = false;

  bool get _reduceMotion => MediaQuery.of(context).disableAnimations;

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _setHovered(bool value) {
    if (!widget.enabled || _hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = _reduceMotion;
    final scale = _pressed
        ? widget.pressedScale
        : _hovered && !reduceMotion
            ? widget.hoverScale
            : 1.0;

    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: widget.enabled ? (_) => _setHovered(true) : null,
      onExit: widget.enabled ? (_) => _setHovered(false) : null,
      child: Listener(
        onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
        onPointerUp: widget.enabled ? (_) => _setPressed(false) : null,
        onPointerCancel: widget.enabled ? (_) => _setPressed(false) : null,
        child: AnimatedContainer(
          duration: reduceMotion ? AppMotion.instant : AppMotion.fast,
          curve: AppMotion.curve,
          transform: Matrix4.translationValues(
            0,
            _hovered && !reduceMotion ? widget.hoverLift : 0,
            0,
          ),
          child: AnimatedScale(
            scale: scale,
            duration: reduceMotion
                ? AppMotion.instant
                : _pressed
                    ? AppMotion.press
                    : AppMotion.fast,
            curve: AppMotion.curve,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
