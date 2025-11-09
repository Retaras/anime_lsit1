import 'package:flutter/scheduler.dart';

/// Добавляет задержку перед выполнением обратного вызова.
extension FutureExtensions on Future {
  Future delayed(Duration duration) {
    return Future.delayed(duration);
  }
}