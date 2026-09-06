import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const _purple = Color(0xFF6C4AB6);
const _teal = Color(0xFF00A896);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool create = false;
  bool busy = false;
  bool showPassword = false;

  void _snack(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> submit() async {
    if (!email.text.contains('@') || password.text.length < 6) {
      _snack('Enter a valid email and password of at least 6 characters.');
      return;
    }
    setState(() => busy = true);
    try {
      if (create) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email.text.trim(), password: password.text);
        _snack('Account created. Please wait for Admin approval.');
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.text.trim(), password: password.text);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _snack(e.message ?? e.code);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF432371), Color(0xFF7B4BB7), Color(0xFF00A896)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(children: [
                  Container(width: 82, height: 82, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [_purple, _teal])), child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 44)),
                  const SizedBox(height: 16),
                  Text('Daily Hisab', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const Text('Shared business accounting'),
                  const SizedBox(height: 24),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
                  const SizedBox(height: 12),
                  TextField(controller: password, obscureText: !showPassword, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => showPassword = !showPassword), icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility)))),
                  const SizedBox(height: 18),
                  SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : submit, child: busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(create ? 'CREATE ACCOUNT' : 'LOGIN'))),
                  TextButton(onPressed: busy ? null : () => setState(() => create = !create), child: Text(create ? 'Already have an account? Login' : 'New user? Create account')),
                  const Text('New accounts require Admin approval before access.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                ]),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
