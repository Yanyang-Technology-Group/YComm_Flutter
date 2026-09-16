import 'package:flutter/material.dart';

import '../../core/widgets/app_logo.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          const AppLogo(),
          const SizedBox(height: 24),
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    ),
  );
}

class AuthError extends StatelessWidget {
  const AuthError(this.message, {super.key});
  final String? message;
  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Semantics(
          liveRegion: true,
          child: Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              message!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                height: 1.6,
              ),
            ),
          ),
        );
}
