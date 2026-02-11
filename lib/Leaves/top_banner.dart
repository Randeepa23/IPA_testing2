import 'dart:async';
import 'package:flutter/material.dart';

class TopBanner {
  static OverlayEntry? _entry;
  static Timer? _timer;

static void show(
  BuildContext context, {
  required String title,
  required String message,
  IconData? icon,
  String? leftButtonText,
  String rightButtonText = "OK",
  VoidCallback? onLeftTap,
  VoidCallback? onRightTap,
  Duration duration = const Duration(seconds: 4),
}) {
    hide();

    final overlay = Overlay.of(context);

    _entry = OverlayEntry(
      builder: (_) => _TopBannerWidget(
        title: title,
        message: message,
        icon: icon,   // ← add
        leftButtonText: leftButtonText,
        rightButtonText: rightButtonText,
        onLeftTap: () {
          hide();
          onLeftTap?.call();
        },
        onRightTap: () {
          hide();
          onRightTap?.call();
        },
      ),
    );

    overlay.insert(_entry!);

    _timer = Timer(duration, () {
      hide();
    });
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _TopBannerWidget extends StatefulWidget {
  final String title;
  final String message;
  final String? leftButtonText;
  final String rightButtonText;
  final VoidCallback? onLeftTap;
  final VoidCallback? onRightTap;
  final IconData? icon;

  const _TopBannerWidget({
    required this.title,
    required this.message,
    this.icon,
    required this.leftButtonText,
    required this.rightButtonText,
    this.onLeftTap,
    this.onRightTap,
  });

  @override
  State<_TopBannerWidget> createState() => _TopBannerWidgetState();
}

class _TopBannerWidgetState extends State<_TopBannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _slide = Tween<Offset>(begin: const Offset(0, -1.2), end: const Offset(0, 0))
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);

    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned(
            top: topPad + 10,
            left: 14,
            right: 14,
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.22)),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 18,
                          color: Colors.black.withOpacity(0.18),
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: DefaultTextStyle(
                      style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Row(
                          children: [
                            if (widget.icon != null)
                              Icon(widget.icon, color: Colors.black, size: 24),

                            if (widget.icon != null)
                              const SizedBox(width: 10),

                            Expanded(
                              child: Text(
                                widget.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),

                          const SizedBox(height: 8),
                          Text(
                            widget.message,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.85),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (widget.leftButtonText != null)
                                _pillButton(
                                  text: widget.leftButtonText!,
                                  onTap: widget.onLeftTap,
                                  bg: Colors.white.withOpacity(0.35),
                                ),

                              if (widget.leftButtonText != null)
                                const SizedBox(width: 10),

                              _pillButton(
                                text: widget.rightButtonText,
                                onTap: widget.onRightTap,
                                bg: Colors.white.withOpacity(0.45),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillButton({
    required String text,
    required VoidCallback? onTap,
    required Color bg,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
    );
  }
}
