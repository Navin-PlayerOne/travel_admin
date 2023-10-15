import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';

import '../auth/auth.dart';
import 'home.dart';
import 'loginpage.dart';

class AuthState extends StatelessWidget {
  const AuthState({super.key});

  @override
  Widget build(BuildContext context) {
    final value = context.watch<AuthAPI>().status;
    print('TOP CHANGE Value changed to: $value!');

    return value == AuthStatus.uninitialized
        ? const Scaffold(
            body: SpinKitDoubleBounce(
              color: Colors.indigo,
              size: 300,
            ),
          )
        : value == AuthStatus.authenticated
            ? MyHomePage()
            : const LoginPage();
  }
}
