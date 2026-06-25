import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // アイコン
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.water_drop_rounded,
                    size: 52, color: cs.primary),
              ),
              const SizedBox(height: 24),
              Text(
                '腹膜透析記録',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '透析記録をかんたんに管理',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: cs.onSurface.withOpacity(0.6)),
              ),
              const Spacer(flex: 2),
              // Googleログインボタン
              Consumer<AppProvider>(
                builder: (_, provider, __) => FilledButton.icon(
                  onPressed: provider.isLoading ? null : () => provider.login(),
                  icon: provider.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.login),
                  label: Text(provider.isLoading ? 'ログイン中...' : 'Google でログイン'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'ログインするとデータがクラウドに保存され\niPhone・iPad で同期されます',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurface.withOpacity(0.5)),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
