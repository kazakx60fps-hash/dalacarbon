/* DalaCarbon AI — жаңа құпиясөз формасы: күш көрсеткіші және қайталаудың сәйкестігі.
 * Ережелер app/validators.py-мен бірдей; шешуші тексеру — серверде. */
(() => {
  'use strict';

  const form = document.getElementById('reset-form');
  if (!form) return;

  const MSG = {
    password_required: 'Құпиясөзді енгізіңіз',
    password_short: 'Құпиясөз кемінде 8 таңбадан тұруы тиіс',
    password_long: 'Құпиясөз 128 таңбадан аспауы тиіс',
    password_case: 'Құпиясөзде бас және кіші әріп болуы тиіс',
    password_digit: 'Құпиясөзде кемінде бір сан болуы тиіс',
    password_is_username: 'Құпиясөз логинмен бірдей болмауы тиіс',
    confirm_required: 'Құпиясөзді қайталап енгізіңіз',
    confirm_mismatch: 'Енгізілген құпиясөздер бір-біріне сәйкес келмейді',
  };
  const pw = document.getElementById('password');
  const confirm = document.getElementById('password_confirm');
  const username = (document.getElementById('username') || {}).value || '';

  const checks = (v) => ({
    length: v.length >= 8,
    case: /\p{Ll}/u.test(v) && /\p{Lu}/u.test(v),
    digit: /\p{Nd}/u.test(v),
    special: /[^\p{L}\p{N}]/u.test(v),
  });

  const RULES = {
    password() {
      const v = pw.value;
      if (!v) return MSG.password_required;
      if (v.length > 128) return MSG.password_long;
      const c = checks(v);
      if (!c.length) return MSG.password_short;
      if (!c.case) return MSG.password_case;
      if (!c.digit) return MSG.password_digit;
      if (username && v.toLowerCase() === username.toLowerCase()) return MSG.password_is_username;
      return '';
    },
    password_confirm() {
      if (!confirm.value) return MSG.confirm_required;
      return confirm.value === pw.value ? '' : MSG.confirm_mismatch;
    },
  };

  function show(name) {
    const message = RULES[name]();
    const input = document.getElementById(name);
    const line = document.getElementById(`${name}-error`);
    input.setAttribute('aria-invalid', message ? 'true' : 'false');
    line.querySelector('.field__error-text').textContent = message;
    line.hidden = !message;
    input.closest('.field').classList.toggle('field--invalid', !!message);
    return message;
  }

  const touched = new Set(form.querySelector('[aria-invalid="true"]') ? ['password', 'password_confirm'] : []);
  [pw, confirm].forEach((input) => {
    input.addEventListener('blur', () => { if (input.value) { touched.add(input.id); show(input.id); } });
    input.addEventListener('input', () => {
      if (touched.has(input.id)) show(input.id);
      if (input === pw && touched.has('password_confirm')) show('password_confirm');
    });
  });

  // Күш көрсеткіші (тіркелу бетіндегідей)
  const meter = form.querySelector('.meter');
  const label = document.getElementById('password-strength');
  const LEVELS = ['Күші: —', 'Әлсіз', 'Орташа', 'Жақсы', 'Күшті'];
  function strength() {
    const c = checks(pw.value);
    form.querySelectorAll('.rule').forEach((li) => {
      const ok = !!c[li.dataset.rule];
      li.classList.toggle('rule--ok', ok);
      li.querySelector('.rule__state').textContent = ok ? ' — орындалды' : ' — орындалмаған';
    });
    const level = pw.value ? Object.values(c).filter(Boolean).length : 0;
    meter.dataset.level = String(level);
    label.textContent = pw.value ? LEVELS[Math.max(level, 1)] : LEVELS[0];
  }
  pw.addEventListener('input', strength);
  strength();

  const submit = document.getElementById('reset-submit');
  form.addEventListener('submit', (event) => {
    const bad = ['password', 'password_confirm'].find((name) => show(name));
    if (bad) {
      event.preventDefault();
      document.getElementById(bad).focus();
      return;
    }
    window.DalaCarbon.setLoading(submit, 'Сақталуда…');
  });
})();
