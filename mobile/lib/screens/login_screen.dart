// Кіру экраны: жоғарыда далалық иллюстрация, төменде көтеріліп шығатын «парақ» формасы.
// Кіру басылғанда — бұлдыр жүктелу (спутник орбитада), сосын басты бет.
import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/fade_route.dart';
import '../widgets/scan_loading.dart';
import '../widgets/steppe_header.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  final _form = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _hidden = true;
  bool _remember = true;
  bool _loading = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _intro.dispose();
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_form.currentState?.validate() ?? false) _enter(_nameFrom(_login.text));
  }

  String _nameFrom(String login) {
    final v = login.trim();
    final base = v.contains('@') ? v.split('@').first : v;
    return base.isEmpty ? 'Фермер' : base;
  }

  void _enter(String name) {
    setState(() => _loading = true);
    _timer = Timer(const Duration(milliseconds: 2300), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(fadeRoute(HomeScreen(name: name), ms: 700));
    });
  }

  /// Жолдардың кезекпен шығуы.
  Widget _stagger(int i, Widget child) {
    final start = (0.18 + i * 0.07).clamp(0.0, 0.7).toDouble();
    final anim = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, (start + 0.3).clamp(0.0, 1.0).toDouble(), curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final headerH = MediaQuery.sizeOf(context).height * 0.34;
    final sheetIn = CurvedAnimation(parent: _intro, curve: const Interval(0, 0.55, curve: Curves.easeOutCubic));

    return Scaffold(
      backgroundColor: Dc.paper,
      body: Stack(children: [
        SingleChildScrollView(
          child: Column(children: [
            SizedBox(
              width: double.infinity, // әйтпесе Stack логотиптің еніне дейін тарылады
              height: headerH,
              child: Stack(children: [
                const Positioned.fill(child: SteppeHeader()),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: FadeTransition(opacity: sheetIn, child: const BrandRow(logo: 30, text: 19)),
                  ),
                ),
              ]),
            ),
            SlideTransition(
              position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(sheetIn),
              child: Transform.translate(
                offset: const Offset(0, -28),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Dc.paper,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, -6))],
                  ),
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                  child: _buildForm(),
                ),
              ),
            ),
          ]),
        ),
        if (_loading)
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 350),
              builder: (context, v, child) => Opacity(opacity: v, child: child),
              child: const ScanLoading(),
            ),
          ),
      ]),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _stagger(0, const Text('Қош келдіңіз!',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Dc.ink, letterSpacing: -0.5))),
        const SizedBox(height: 4),
        _stagger(1, const Text('Алқаптарыңыздың көміртегі есебін бақылаңыз',
            style: TextStyle(color: Dc.muted, fontSize: 14))),
        const SizedBox(height: 22),
        _stagger(
          2,
          TextFormField(
            controller: _login,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            decoration: const InputDecoration(
              hintText: 'Логин немесе email',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Логин немесе email енгізіңіз' : null,
          ),
        ),
        const SizedBox(height: 14),
        _stagger(
          3,
          TextFormField(
            controller: _password,
            obscureText: _hidden,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Құпиясөз',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: _hidden ? 'Құпиясөзді көрсету' : 'Құпиясөзді жасыру',
                icon: Icon(_hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _hidden = !_hidden),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Құпиясөзді енгізіңіз';
              if (v.length < 8) return 'Құпиясөз кемінде 8 таңба';
              return null;
            },
          ),
        ),
        const SizedBox(height: 6),
        _stagger(
          4,
          Row(children: [
            SizedBox(
              width: 32,
              child: Checkbox(
                value: _remember,
                activeColor: Dc.gold,
                checkColor: Dc.ink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                onChanged: (v) => setState(() => _remember = v ?? false),
              ),
            ),
            const Text('Мені есте сақта', style: TextStyle(fontSize: 13, color: Dc.ink)),
            const Spacer(),
            TextButton(
              onPressed: () => _toast('Қалпына келтіру сілтемесі email-ге жіберіледі (сайттағыдай).'),
              child: const Text('Құпиясөзді ұмыттыңыз ба?',
                  style: TextStyle(color: Dc.green2, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        _stagger(5, GoldButton(label: 'Кіру', onPressed: _submit)),
        const SizedBox(height: 18),
        _stagger(6, const _OrDivider()),
        const SizedBox(height: 16),
        _stagger(
          7,
          Row(children: [
            Expanded(
              child: _SocialButton(
                label: 'Google',
                icon: const Text('G',
                    style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w900, fontSize: 18)),
                onTap: () => _toast('Google арқылы кіру келесі нұсқада қосылады.'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SocialButton(
                label: 'Apple',
                icon: const Icon(Icons.apple, size: 22, color: Dc.ink),
                onTap: () => _toast('Apple арқылы кіру келесі нұсқада қосылады.'),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        _stagger(
          8,
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('Аккаунт жоқ па?', style: TextStyle(color: Dc.muted, fontSize: 13.5)),
            TextButton(
              onPressed: () => _toast('Тіркелу әзірге сайтта: /register'),
              child: const Text('Тіркелу', style: TextStyle(color: Dc.ink, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
        _stagger(
          9,
          Center(
            child: TextButton.icon(
              onPressed: () => _enter('Демо фермер'),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18, color: Dc.gold),
              label: const Text('Демо режимде көру',
                  style: TextStyle(color: Dc.gold, fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Алтын градиентті негізгі батырма (сайттағы «Кіру» батырмасындай).
class GoldButton extends StatelessWidget {
  const GoldButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [Color(0xFFDDA43C), Color(0xFFF3CD7E)]),
        boxShadow: [BoxShadow(color: Dc.gold.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: SizedBox(
            height: 56,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(label, style: const TextStyle(color: Dc.ink, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: Dc.ink, size: 20),
            ]),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(children: [
      Expanded(child: Divider(color: Dc.line)),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Text('немесе жалғастырыңыз', style: TextStyle(color: Dc.muted, fontSize: 12.5)),
      ),
      Expanded(child: Divider(color: Dc.line)),
    ]);
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.label, required this.icon, required this.onTap});

  final String label;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Dc.input,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          height: 54,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            icon,
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: Dc.ink, fontWeight: FontWeight.w700, fontSize: 15)),
          ]),
        ),
      ),
    );
  }
}
