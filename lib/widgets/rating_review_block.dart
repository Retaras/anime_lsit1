import 'package:flutter/material.dart';

class RatingReviewBlock extends StatefulWidget {
  final int currentRating;
  final TextEditingController reviewController;
  final FocusNode reviewFocusNode; // <-- 1. Добавляем параметр FocusNode
  final ValueChanged<int>? onRatingChanged;

  const RatingReviewBlock({
    super.key,
    required this.currentRating,
    required this.reviewController,
    required this.reviewFocusNode, // <-- 2. Добавляем параметр в конструктор
    this.onRatingChanged,
  });

  @override
  State<RatingReviewBlock> createState() => _RatingReviewBlockState();
}

class _RatingReviewBlockState extends State<RatingReviewBlock>
    with SingleTickerProviderStateMixin {
  late int rating;
  late AnimationController _shimmerController;

  final List<String> quickPhrases = [
    "Захватывало дух",
    "Не зацепило",
    "Скучно",
    "Эпично",
    "Романтично",
    "Интригующе",
    "Много экшена",
    "Глубокий сюжет",
  ];

  @override
  void initState() {
    super.initState();
    rating = widget.currentRating;
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant RatingReviewBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentRating != oldWidget.currentRating) {
      setState(() {
        rating = widget.currentRating;
      });
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Color _getColor(int value) {
    if (value <= 0) return const Color(0xFF4A4A4A);
    if (value <= 3) return const Color(0xFFEF4444);
    if (value <= 5) return const Color(0xFFF59E0B);
    if (value <= 7) return const Color(0xFFFBBF24);
    if (value <= 9) return const Color(0xFF10B981);
    return const Color(0xFF8B5CF6);
  }

  String _getRatingLabel(int value) {
    if (value == 0) return 'Не оценено';
    if (value <= 3) return 'Разочарование';
    if (value <= 5) return 'Нормально';
    if (value <= 7) return 'Понравилось';
    if (value <= 9) return 'Восхитительно';
    return 'Шедевр';
  }

  IconData _getRatingIcon(int value) {
    if (value == 0) return Icons.star_border;
    if (value <= 3) return Icons.sentiment_dissatisfied;
    if (value <= 5) return Icons.sentiment_neutral;
    if (value <= 7) return Icons.sentiment_satisfied;
    if (value <= 9) return Icons.sentiment_very_satisfied;
    return Icons.auto_awesome;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Секция оценки
        const Text(
          'Ваша оценка',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Визуальная карточка с оценкой
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _getColor(rating).withOpacity(0.15),
                _getColor(rating).withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _getColor(rating).withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              // Текущая оценка и иконка
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          _getColor(rating),
                          _getColor(rating).withOpacity(0.7),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _getColor(rating).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      _getRatingIcon(rating),
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rating == 0 ? '—' : '$rating / 10',
                        style: TextStyle(
                          color: _getColor(rating),
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getRatingLabel(rating),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Слайдер
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 8,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 28),
                  activeTrackColor: _getColor(rating),
                  inactiveTrackColor: const Color(0xFF2A2A2A),
                  thumbColor: _getColor(rating),
                  overlayColor: _getColor(rating).withOpacity(0.3),
                ),
                child: Slider(
                  value: rating.toDouble(),
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: rating == 0 ? 'Не оценено' : '$rating',
                  onChanged: (value) {
                    setState(() {
                      rating = value.toInt();
                    });
                    widget.onRatingChanged?.call(rating);
                  },
                ),
              ),
              
              // Шкала значений
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(11, (i) {
                    final isActive = i <= rating;
                    return Text(
                      '$i',
                      style: TextStyle(
                        color: isActive
                            ? _getColor(i)
                            : Colors.white.withOpacity(0.3),
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Секция отзыва
        Row(
          children: [
            const Text(
              'Ваш отзыв',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Colors.orangeAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Быстрые фразы',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              tooltip: 'Выбрать фразу',
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              offset: const Offset(0, 45),
              onSelected: (value) {
                widget.reviewController.text = value;
              },
              itemBuilder: (context) => quickPhrases
                  .map(
                    (phrase) => PopupMenuItem(
                      value: phrase,
                      child: Row(
                        children: [
                          Icon(
                            Icons.format_quote,
                            color: Colors.white.withOpacity(0.5),
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            phrase,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Поле отзыва
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: TextField(
            // <-- 3. ПРИВЯЖЫВАЕМ FOCUSNODE И КОНТРОЛЛЕР
            focusNode: widget.reviewFocusNode,
            controller: widget.reviewController,
            maxLines: 5,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: 'Напишите, что вы думаете об этом аниме...',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 14,
              ),
              filled: false,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }
}