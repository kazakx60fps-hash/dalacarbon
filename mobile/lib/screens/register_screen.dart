// Тіркелу: сайттағыдай өрістер мен ережелер; тексеру серверде (/api/v1/auth/register), қателер өрістің астында.
import 'package:flutter/material.dart';

import '../api/api.dart';
import '../theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/fade_route.dart';
import '../widgets/ui.dart';
import 'home_shell.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _c = {for (final k in ['full_name', 'email', 'username', 'password', 'password_confirm']) k: TextEditingController()};
  String? _region;
  String? _farm;
  bool _newsletter = false;
  bool _hidden = true;
  bool _busy = false;
  Map<String, String> _errors = {};
  String? _banner;
  late final Future<Json> _meta = Api.instance.meta();

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, bool> get _checks {
    final pw = _c['password']!.text;
    return {
      'Кемінде 8 таңба': pw.length >= 8,
      'Бас және кіші әріп': RegExp(r'\p{Ll}', unicode: true).hasMatch(pw) && RegExp(r'\p{Lu}', unicode: true).hasMatch(pw),
      'Кемінде бір сан': RegExp(r'\p{Nd}', unicode: true).hasMatch(pw),
      'Арнайы таңба (ұсынылады)': RegExp(r'[^\p{L}\p{N}]', unicode: true).hasMatch(pw),
    };
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _errors = {};
      _banner = null;
    });
    try {
      await Api.instance.register({
        for (final e in _c.entries) e.key: e.value.text,
        'region': _region ?? '',
        'farm_type': _farm ?? '',
        'newsletter': _newsletter,
      });
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(fadeRoute(const HomeShell()), (r) => false);
    } on ApiException catch (e) {
      setState(() {
        _errors = e.errors;
        _banner = e.errors.isEmpty ? e.message : 'Белгіленген өрістерді тексеріңіз';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String key, String hint, IconData icon, {TextInputType? type, bool password = false, String? helper}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _c[key],
        keyboardType: type,
        obscureText: password && _hidden,
        onChanged: key == 'password' ? (_) => setState(() {}) : null,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon),
          errorText: _errors[key],
          helperText: helper,
          suffixIcon: password
              ? IconButton(
                  icon: Icon(_hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _hidden = !_hidden),
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checks = _checks;
    final level = _c['password']!.text.isEmpty ? 0 : checks.values.where((v) => v).length;
    const levelText = ['Күші: —', 'Әлсіз', 'Орташа', 'Жақсы', 'Күшті'];
    const levelColor = [Dc.line, Dc.danger, Color(0xFFF79009), Dc.gold, Dc.green2];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Dc.paper,
        surfaceTintColor: Colors.transparent,
        title: const BrandRow(logo: 26, text: 17),
      ),
      body: FutureBuilder<Json>(
        future: _meta,
        builder: (context, snap) {
          if (snap.hasError) {
            return LoadError(message: '${snap.error}', onRetry: () => setState(() {}));
          }
          final meta = snap.data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
            children: [
              Rise(
                index: 0,
                child: const Text('Аккаунт ашу',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Dc.ink, letterSpacing: -0.5)),
              ),
              const Text('Топырағыңыздағы көміртегін табысқа айналдырыңыз', style: TextStyle(color: Dc.muted)),
              const SizedBox(height: 18),
              if (_banner != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(_banner!, style: const TextStyle(color: Dc.danger, fontWeight: FontWeight.w600)),
                ),
              _field('full_name', 'Аты-жөні немесе шаруашылық атауы', Icons.person_outline_rounded),
              _field('email', 'Email', Icons.mail_outline_rounded, type: TextInputType.emailAddress),
              _field('username', 'Логин', Icons.alternate_email_rounded,
                  helper: 'Латын әріптері, сандар және «_», 4–32 таңба'),
              _field('password', 'Құпиясөз', Icons.lock_outline_rounded, password: true),
              Row(children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: i < level ? levelColor[level] : Dc.line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Text(levelText[level], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: levelColor[level])),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 12, runSpacing: 4, children: [
                for (final e in checks.entries)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(e.value ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                        size: 14, color: e.value ? Dc.green2 : Dc.muted),
                    const SizedBox(width: 4),
                    Text(e.key, style: TextStyle(fontSize: 12, color: e.value ? Dc.green2 : Dc.muted)),
                  ]),
              ]),
              const SizedBox(height: 12),
              _field('password_confirm', 'Құпиясөзді қайталау', Icons.lock_outline_rounded, password: true),
              DropdownButtonFormField<String>(
                initialValue: _region,
                isExpanded: true,
                decoration: InputDecoration(hintText: 'Облыс', errorText: _errors['region'], prefixIcon: const Icon(Icons.place_outlined)),
                items: [
                  for (final r in (meta?['regions'] as List? ?? const []).cast<Json>())
                    DropdownMenuItem(value: r['key'] as String, child: Text(r['label'] as String)),
                ],
                onChanged: (v) => setState(() => _region = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _farm,
                isExpanded: true,
                decoration: InputDecoration(
                    hintText: 'Шаруашылық түрі', errorText: _errors['farm_type'], prefixIcon: const Icon(Icons.agriculture_outlined)),
                items: [
                  for (final f in (meta?['farm_types'] as List? ?? const []).cast<Json>())
                    DropdownMenuItem(value: f['key'] as String, child: Text(f['label'] as String)),
                ],
                onChanged: (v) => setState(() => _farm = v),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _newsletter,
                activeColor: Dc.gold,
                checkColor: Dc.ink,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Агро-кеңестер мен жаңалықтарды email арқылы алғым келеді (міндетті емес)',
                    style: TextStyle(fontSize: 13)),
                onChanged: (v) => setState(() => _newsletter = v ?? false),
              ),
              const SizedBox(height: 10),
              GoldButton(label: 'Аккаунт ашу', busy: _busy, onPressed: _submit),
              const SizedBox(height: 10),
              const Text(
                '«Аккаунт ашу» батырмасын басу арқылы DalaCarbon AI пайдалану шарттарымен келісесіз.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Dc.muted),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Аккаунтыңыз бар ма?', style: TextStyle(color: Dc.muted)),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Кіру', style: TextStyle(color: Dc.ink, fontWeight: FontWeight.w800)),
                ),
              ]),
            ],
          );
        },
      ),
    );
  }
}
