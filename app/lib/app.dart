import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/device/device_posture_cubit.dart';
import 'core/storage/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/presentation/pages/onboarding_screen.dart';
import 'features/reader/presentation/bloc/reader_bloc.dart';
import 'features/workspace/presentation/bloc/active_workspace_bloc.dart';
import 'features/workspace/presentation/pages/workspace_screen.dart';
import 'injection_container.dart';

class SplitMindApp extends StatefulWidget {
  const SplitMindApp({super.key});

  @override
  State<SplitMindApp> createState() => _SplitMindAppState();
}

class _SplitMindAppState extends State<SplitMindApp> {
  final _settings = sl<AppSettings>();
  late bool _onboarded = _settings.onboardingComplete;
  ReaderLaunchAction _launchAction = ReaderLaunchAction.none;

  Future<void> _finishOnboarding(ReaderLaunchAction action) async {
    await _settings.setOnboardingComplete();
    setState(() {
      _onboarded = true;
      _launchAction = action;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        
        // App-wide singletons: the Mediator and the device posture.

        
        BlocProvider.value(value: sl<ActiveWorkspaceBloc>()),
        BlocProvider.value(value: sl<DevicePostureCubit>()),
      ],
      child: MaterialApp(
        title: 'SplitMind',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: _onboarded
            ? WorkspaceScreen(launchAction: _launchAction)
            : OnboardingScreen(onFinished: _finishOnboarding),
      ),
    );
  }
}
