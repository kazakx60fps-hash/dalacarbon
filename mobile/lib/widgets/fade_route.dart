// Экрандар арасындағы жұмсақ ауысу (видеодағыдай fade).
import 'package:flutter/material.dart';

Route<T> fadeRoute<T>(Widget page, {int ms = 650}) {
  return PageRouteBuilder<T>(
    transitionDuration: Duration(milliseconds: ms),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      child: child,
    ),
  );
}
