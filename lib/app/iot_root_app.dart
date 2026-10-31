import 'package:flutter/material.dart';

import '../features/templates/data/template_repository.dart';
import '../features/templates/presentation/controllers/template_controller.dart';
import '../features/templates/presentation/pages/home_shell.dart';
import 'theme/app_theme.dart';
import '../features/auth/presentation/login_page.dart';

class IotRootApp extends StatefulWidget {
  const IotRootApp({super.key, this.controller});
  final TemplateController? controller;

  @override
  State<IotRootApp> createState() => _IotRootAppState();
}

class _IotRootAppState extends State<IotRootApp> with WidgetsBindingObserver {
  late final TemplateController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = widget.controller ?? TemplateController(TemplateRepository());
    _controller.initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Background states intentionally keep MQTT alive. Detached means the
    // Flutter view has been removed, such as when the Android task is swiped
    // away, so this is the one lifecycle transition that closes the session.
    if (state == AppLifecycleState.detached) {
      _controller.disconnect();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => MaterialApp(
        title: 'IoTRoot Templates',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _controller.themeMode,
        home: Builder(
          builder: (context) {
            if (_controller.initializing) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return _controller.authenticated
                ? HomeShell(controller: _controller)
                : LoginPage(controller: _controller);
          },
        ),
      ),
    );
  }
}
