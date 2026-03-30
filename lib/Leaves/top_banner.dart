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
    bool isSuccess = false,
    bool isError = false,
    Duration duration = const Duration(seconds: 4),
  }) {
    hide();

    final overlay = Overlay.of(context);

    _entry = OverlayEntry(
      builder: (_) => _TopBannerWidget(
        title: title,
        message: message,
        icon: icon,
        leftButtonText: leftButtonText,
        rightButtonText: rightButtonText,
        isSuccess: isSuccess,
        isError: isError,
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

    _timer = Timer(duration, hide);
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
  final bool isSuccess;
  final bool isError;

  const _TopBannerWidget({
    required this.title,
    required this.message,
    this.icon,
    required this.leftButtonText,
    required this.rightButtonText,
    this.onLeftTap,
    this.onRightTap,
    required this.isSuccess,
    required this.isError,
  });

  @override
  State<_TopBannerWidget> createState() => _TopBannerWidgetState();
}

class _TopBannerWidgetState extends State<_TopBannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
    );
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool get _isSuccess =>
      widget.isSuccess || widget.icon == Icons.check_circle;

  bool get _isError =>
      widget.isError ||
      widget.icon == Icons.cancel ||
      widget.icon == Icons.error ||
      widget.icon == Icons.error_outline;

  List<Color> get _gradientColors {
    if (_isSuccess) {
      return const [Color(0xFF2E7D32), Color(0xFF1B5E20)];
    }
    if (_isError) {
      return const [Color(0xFFD32F2F), Color(0xFFB71C1C)];
    }
    return const [Color(0xFF1E88E5), Color(0xFF0D47A1)];
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    const radius = 20.0;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned(
            top: topPad + 8,
            left: 14,
            right: 14,
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: ScaleTransition(
                  scale: _scale,
                  alignment: Alignment.topCenter,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 24,
                          spreadRadius: 0,
                          color: Colors.black.withOpacity(0.22),
                          offset: const Offset(0, 12),
                        ),
                        BoxShadow(
                          blurRadius: 8,
                          color: _gradientColors.first.withOpacity(0.35),
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _gradientColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.22),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.icon != null) ...[
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.20),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.28),
                                        ),
                                      ),
                                      child: Icon(
                                        widget.icon,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.title,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: -0.2,
                                            height: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          widget.message,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                Colors.white.withOpacity(0.92),
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: TopBanner.hide,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Icon(
                                          Icons.close_rounded,
                                          color: Colors.white.withOpacity(0.85),
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (widget.leftButtonText != null) ...[
                                    _pillButton(
                                      text: widget.leftButtonText!,
                                      onTap: widget.onLeftTap,
                                      filled: false,
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  _pillButton(
                                    text: widget.rightButtonText,
                                    onTap: widget.onRightTap,
                                    filled: true,
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillButton({
    required String text,
    required VoidCallback? onTap,
    required bool filled,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            color: filled
                ? Colors.white.withOpacity(0.32)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withOpacity(filled ? 0 : 0.45),
              width: 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
