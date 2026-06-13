import 'package:flutter/material.dart';

class ScoreBadge extends StatelessWidget {
  final double score;
  final String band;
  final double size;

  const ScoreBadge({
    super.key,
    required this.score,
    required this.band,
    this.size = 72,
  });

  Color get _color {
    switch (band) {
      case 'excellent':
        return const Color(0xFF2E7D32);
      case 'good':
        return const Color(0xFFF9A825);
      case 'caution':
        return const Color(0xFFEF6C00);
      case 'poor':
        return const Color(0xFFC62828);
      default:
        return Colors.grey;
    }
  }

  String get _label {
    switch (band) {
      case 'excellent':
        return 'Excellent';
      case 'good':
        return 'Good';
      case 'caution':
        return 'Caution';
      case 'poor':
        return 'Poor';
      default:
        return band;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 6,
                  backgroundColor: _color.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation(_color),
                ),
              ),
              Text(
                score.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: size * 0.3,
                  fontWeight: FontWeight.bold,
                  color: _color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: _color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _color,
            ),
          ),
        ),
      ],
    );
  }
}
