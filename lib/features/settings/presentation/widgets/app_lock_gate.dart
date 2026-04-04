import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/components/glass_card.dart';
import '../../../../shared/components/primary_button.dart';
import '../../domain/entities/app_preferences.dart';
import '../controllers/app_preferences_controller.dart';

final appLockSessionProvider = StateProvider<bool>((ref) => false);

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  final TextEditingController _pinController = TextEditingController();
  String? _errorText;
  AppPreferences _lastKnownPreferences = const AppPreferences.defaults();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pinController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_lastKnownPreferences.appLockEnabled &&
          _lastKnownPreferences.hasPin) {
        ref.read(appLockSessionProvider.notifier).state = false;
      }
    }
  }

  void _unlock() {
    final enteredPin = _pinController.text.trim();
    if (enteredPin == _lastKnownPreferences.appLockPin) {
      ref.read(appLockSessionProvider.notifier).state = true;
      setState(() {
        _errorText = null;
      });
      _pinController.clear();
      return;
    }

    setState(() {
      _errorText = 'Incorrect PIN. Try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final preferencesState = ref.watch(appPreferencesControllerProvider);
    final sessionUnlocked = ref.watch(appLockSessionProvider);
    final preferences = preferencesState.valueOrNull ?? _lastKnownPreferences;
    _lastKnownPreferences = preferences;

    if (preferencesState.isLoading && preferencesState.valueOrNull == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!preferences.appLockEnabled || !preferences.hasPin) {
      return widget.child;
    }

    if (sessionUnlocked) {
      return widget.child;
    }

    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.aboutAppName)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: GlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unlock app',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your PIN to continue.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: 'PIN',
                        errorText: _errorText,
                        counterText: '',
                      ),
                      onChanged: (_) {
                        if (_errorText == null) {
                          return;
                        }
                        setState(() {
                          _errorText = null;
                        });
                      },
                      onSubmitted: (_) => _unlock(),
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Unlock',
                      icon: Icons.lock_open_outlined,
                      onPressed: _unlock,
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
}
