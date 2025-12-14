import 'package:flutter/services.dart';

class HapticService {
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;
  HapticService._internal();

  bool _isEnabled = true;

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  void light() {
    if (!_isEnabled) return;
    HapticFeedback.lightImpact();
  }

  void medium() {
    if (!_isEnabled) return;
    HapticFeedback.mediumImpact();
  }

  void heavy() {
    if (!_isEnabled) return;
    HapticFeedback.heavyImpact();
  }

  void selection() {
    if (!_isEnabled) return;
    HapticFeedback.selectionClick();
  }

  Future<void> vibrate({int duration = 100}) async {
    if (!_isEnabled) return;
    HapticFeedback.mediumImpact();
  }

  Future<void> success() async {
    if (!_isEnabled) return;
    HapticFeedback.lightImpact();
  }

  Future<void> error() async {
    if (!_isEnabled) return;
    HapticFeedback.heavyImpact();
  }
}