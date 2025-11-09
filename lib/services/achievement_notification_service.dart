import 'package:flutter/material.dart';
import 'dart:async';
import '../models/achievement.dart';

class AchievementNotificationService {
  static final AchievementNotificationService _instance = AchievementNotificationService._internal();
  factory AchievementNotificationService() => _instance;
  static AchievementNotificationService get instance => _instance;
  AchievementNotificationService._internal();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  OverlayEntry? _overlayEntry;
  bool _isShowing = false;
  AnimationController? _animationController;

  void show(Achievement achievement) {
    if (_isShowing) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentContext != null && _animationController == null) {
        _showNotification(achievement);
      }
    });
  }

  void _showNotification(Achievement achievement) {
    _animationController = AnimationController(
      vsync: navigatorKey.currentState!.overlay!,
      duration: const Duration(milliseconds: 600),
    );

    _overlayEntry = OverlayEntry(
      builder: (context) => _buildNotificationWidget(achievement, _animationController!),
    );

    final overlay = navigatorKey.currentState?.overlay;
    if (overlay != null) {
      overlay.insert(_overlayEntry!);
      _isShowing = true;

      _animationController!.forward();

      Future.delayed(const Duration(seconds: 5), () {
        dismiss();
      });
    }
  }

  Future<void> dismiss() async {
    if (!_isShowing || _animationController == null) return;

    await _animationController!.reverse();
    _cleanup();
  }

  void _cleanup() {
    _overlayEntry?.remove();
    _animationController?.dispose();
    _overlayEntry = null;
    _animationController = null;
    _isShowing = false;
  }

  Widget _buildNotificationWidget(Achievement achievement, AnimationController controller) {
    final color = _getCategoryColor(achievement.category);

    final slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutBack,
    ));

    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));

    return Positioned(
      top: 80,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: slideAnimation,
        child: FadeTransition(
          opacity: fadeAnimation,
          child: Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.up,
            onDismissed: (direction) {
              dismiss();
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.95),
                      color.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.6),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getIconData(achievement.iconData),
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Достижение получено!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            achievement.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            achievement.description,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => dismiss(),
                      child: Icon(Icons.close, color: Colors.white.withOpacity(0.8), size: 22),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'ordinary': return const Color(0xFF4CAF50);
      case 'rare': return const Color(0xFF2196F3);
      case 'epic': return const Color(0xFF9C27B0);
      case 'legendary': return const Color(0xFFFF9800);
      case 'divine': return const Color(0xFFFF3366);
      default: return Colors.grey;
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'add_circle': return Icons.add_circle_rounded;
      case 'favorite': return Icons.favorite_rounded;
      case 'star': return Icons.star_rounded;
      case 'rate_review': return Icons.rate_review_rounded;
      case 'swap_horiz': return Icons.swap_horiz_rounded;
      case 'favorite_list': return Icons.favorite;
      case 'star_rate': return Icons.star_rate_rounded;
      case 'comment': return Icons.comment_rounded;
      case 'checklist': return Icons.checklist_rounded;
      case 'list_alt': return Icons.list_alt_rounded;
      case 'diamond': return Icons.diamond_rounded;
      case 'emoji_events': return Icons.emoji_events_rounded;
      default: return Icons.emoji_events_rounded;
    }
  }
}