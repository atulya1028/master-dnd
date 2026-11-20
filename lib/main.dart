import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/auth/auth_bloc.dart';
import 'bloc/dnd/dnd_bloc.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MasterDndApp());
}

class MasterDndApp extends StatelessWidget {
  const MasterDndApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => AuthBloc()),
        BlocProvider<DndBloc>(create: (_) => DndBloc()),
      ],
      child: MaterialApp(
        title: 'Master DND',
        debugShowCheckedModeBanner: false,
        theme: dayTheme,
        home: const AuthGate(),
      ),
    );
  }
}
