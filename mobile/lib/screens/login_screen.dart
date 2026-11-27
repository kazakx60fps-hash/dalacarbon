// Кіру экраны: жоғарыда далалық иллюстрация, төменде көтеріліп шығатын «парақ» формасы.
// Сайттың API-ына нақты кіреді (/api/v1/auth/login), қателер сайттағыдай қазақша.
import 'package:flutter/material.dart';

import '../api/api.dart';
import '../theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/fade_route.dart';
import '../widgets/steppe_header.dart';
import '../widgets/ui.dart';
import 'home_shell.dart';
import 'register_screen.dart';
import 'sheets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.notice});

  final String? notice; // мысалы, «Кіру мерзімі өтті»

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
  bool _busy = false;
  String? _banner;
  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    _banner = widget.notice;
  }

  @override
  void dispose() {
    _intro.dispose();
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _banner = null;
      _errors = {};
    });
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await Api.instance.login(_login.text.trim(), _password.text, remember: _remember);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(fadeRoute(const HomeShell(), ms: 600));
    } on ApiException catch (e) {
      setState(() {
        _errors = e.errors;
        _banner = e.errors.isEmpty ? e.message : null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
    final headerH = MediaQuery.sizeOf(context).height * 0.3;
    final sheetIn = CurvedAnimation(parent: _intro, curve: const Interval(0, 0.55, curve: Curves.easeOutCubic));

    return Scaffold(
      backgroundColor: Dc.paper,
      body: SingleChildScrollView(
        child: Column(children: [
          SizedBox(
            width: double.infinity, // әйтпесе Stack логотиптің еніне дейін тарылады
            height: headerH,
            child: Stack(children: [
              const Positioned.fill(child: SteppeHeader()),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                  child: FadeTransition(
                    opacity: sheetIn,
                    child: Row(children: [
                      const BrandRow(logo: 30, text: 19),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Сервер мекенжайы',
                        icon: const Icon(Icons.dns_outlined, color: Dc.green),
                        onPressed: () async {
                          final changed = await showServerAddress(context);
                          if (changed == true && context.mounted) toast(context, 'Сервер: ${Api.instance.base}');
                        },
                      ),
                    ]),
                  ),
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
    );
  }

  Widget _buildForm() {
    return AutofillGroup(
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _stagger(0, const Text('Қош келдіңіз!',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Dc.ink, letterSpacing: -0.5))),
          const SizedBox(height: 4),
          _stagger(1, const Text('DalaCarbon AI аккаунтыңызға кіріңіз', style: TextStyle(color: Dc.muted, fontSize: 14))),
          const SizedBox(height: 18),
          if (_banner != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Dc.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Dc.danger.withValues(alpha: 0.35)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.error_outline_rounded, color: Dc.danger, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(_banner!, style: const TextStyle(color: Dc.danger, height: 1.4))),
              ]),
            ),
            const SizedBox(height: 14),
          ],
          _stagger(
            2,
            TextFormField(
              controller: _login,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              decoration: InputDecoration(
                hintText: 'Логин немесе email',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                errorText: _errors['login'],
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Логин немесе email өрісін толтырыңыз' : null,
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
                errorText: _errors['password'],
                suffixIcon: IconButton(
                  tooltip: _hidden ? 'Құпиясөзді көрсету' : 'Құпиясөзді жасыру',
                  icon: Icon(_hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _hidden = !_hidden),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Құпиясөзді енгізіңіз' : null,
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
                onPressed: () => showForgot(context),
                child: const Text('Құпиясөзді ұмыттыңыз ба?',
                    style: TextStyle(color: Dc.green2, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          _stagger(5, GoldButton(label: _busy ? 'Кіруде…' : 'Кіру', busy: _busy, onPressed: _submit)),
          const SizedBox(height: 18),
          _stagger(6, const _OrDivider()),
          const SizedBox(height: 16),
          _stagger(
            7,
            Row(children: [
              Expanded(
                child: _SocialButton(
                  label: 'Google',
                  icon: const Text('G', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w900, fontSize: 18)),
                  onTap: () => toast(context, 'Google арқылы кіру әзірге тек сайтта. Мобильдіге келесі нұсқада қосылады.'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SocialButton(
                  label: 'Apple',
                  icon: const Icon(Icons.apple, size: 22, color: Dc.ink),
                  onTap: () => toast(context, 'Apple арқылы кіру жақында қосылады.'),
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
                onPressed: () => Navigator.of(context).push(fadeRoute(const RegisterScreen())),
                child: const Text('Тіркелу', style: TextStyle(color: Dc.ink, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Алтын градиентті негізгі батырма (сайттағы «Кіру» батырмасындай).
class GoldButton extends StatelessWidget {
  const GoldButton({super.key, required this.label, required this.onPressed, this.busy = false});

  final String label;
  final VoidCallback onPressed;
  final bool busy;

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
          onTap: busy ? null : onPressed,
          child: SizedBox(
            height: 56,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (busy)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Dc.ink))
              else
                Text(label, style: const TextStyle(color: Dc.ink, fontSize: 16, fontWeight: FontWeight.w800)),
              if (!busy) ...[
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, color: Dc.ink, size: 20),
              ],
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
