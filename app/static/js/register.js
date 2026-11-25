/* DalaCarbon AI — тіркелу формасы: браузердегі тексеру, құпиясөз күші, көрсету/жасыру.
 * Ережелер app/validators.py-мен бірдей. Сервер бәрібір қайта тексереді. */
(() => {
  'use strict';

  const form = document.getElementById('register-form');
  if (!form) return;

  const MSG = {
    email_required: 'Email өрісін толтырыңыз',
    email_invalid: 'Email форматы дұрыс емес (мысалы, name@example.kz)',
    email_too_long: 'Email 254 таңбадан аспауы тиіс',
    full_name_too_long: 'Аты-жөні 120 таңбадан аспауы тиіс',
    username_required: 'Логин өрісін толтырыңыз',
    username_invalid: 'Логин 4–32 таңбадан тұруы тиіс: латын әріптері, сандар және «_»',
    password_required: 'Құпиясөзді енгізіңіз',
    password_short: 'Құпиясөз кемінде 8 таңбадан тұруы тиіс',
    password_long: 'Құпиясөз 128 таңбадан аспауы тиіс',
    password_case: 'Құпиясөзде бас және кіші әріп болуы тиіс',
    password_digit: 'Құпиясөзде кемінде бір сан болуы тиіс',
    password_is_username: 'Құпиясөз логинмен бірдей болмауы тиіс',
    confirm_required: 'Құпиясөзді қайталап енгізіңіз',
    confirm_mismatch: 'Енгізілген құпиясөздер бір-біріне сәйкес келмейді',
    region_required: 'Облысты таңдаңыз',
    farm_type_required: 'Шаруашылық түрін таңдаңыз',
  };

  const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
  const USERNAME_RE = /^[A-Za-z0-9_]{4,32}$/;

  const checks = (pw) => ({
    length: pw.length >= 8,
    case: /\p{Ll}/u.test(pw) && /\p{Lu}/u.test(pw),
    digit: /\p{Nd}/u.test(pw),
    special: /[^\p{L}\p{N}]/u.test(pw),
  });

  const el = (name) => form.elements.namedItem(name);
  const val = (name) => (el(name) ? el(name).value : '');

  const VALIDATORS = {
    email() {
      const v = val('email').trim();
      if (!v) return MSG.email_required;
      if (v.length > 254) return MSG.email_too_long;
      if (!EMAIL_RE.test(v)) return MSG.email_invalid;
      return '';
    },
    full_name() {
      return val('full_name').trim().replace(/\s+/g, ' ').length > 120 ? MSG.full_name_too_long : '';
    },
    username() {
      const v = val('username').trim();
      if (!v) return MSG.username_required;
      if (!USERNAME_RE.test(v)) return MSG.username_invalid;
      return '';
    },
    password() {
      const v = val('password');
      if (!v) return MSG.password_required;
      if (v.length > 128) return MSG.password_long;
      const c = checks(v);
      if (!c.length) return MSG.password_short;
      if (!c.case) return MSG.password_case;
      if (!c.digit) return MSG.password_digit;
      const u = val('username').trim();
      if (u && v.toLowerCase() === u.toLowerCase()) return MSG.password_is_username;
      return '';
    },
    password_confirm() {
      const v = val('password_confirm');
      if (!v) return MSG.confirm_required;
      if (v !== val('password')) return MSG.confirm_mismatch;
      return '';
    },
    region() { return val('region') ? '' : MSG.region_required; },
    farm_type() { return val('farm_type') ? '' : MSG.farm_type_required; },
  };
  const ORDER = Object.keys(VALIDATORS);

  function setError(name, message) {
    const input = el(name);
    const line = document.getElementById(`${name}-error`);
    if (!input || !line) return;
    input.setAttribute('aria-invalid', message ? 'true' : 'false');
    line.querySelector('.field__error-text').textContent = message;
    line.hidden = !message;
    const field = input.closest('.field');
    if (field) {
      field.classList.toggle('field--invalid', !!field.querySelector('[aria-invalid="true"]'));
    }
  }

  const validate = (name) => {
    const message = VALIDATORS[name]();
    setError(name, message);
    return message;
  };

  // Пайдаланушы өрістен шыққанда тексереміз; қате тұрған өрісті теру кезінде қайта тексереміз.
  const touched = new Set();
  ORDER.forEach((name) => {
    const input = el(name);
    if (!input) return;
    const live = () => {
      if (touched.has(name) || input.getAttribute('aria-invalid') === 'true') validate(name);
      if (name === 'password' && touched.has('password_confirm')) validate('password_confirm');
      if (name === 'username' && touched.has('password')) validate('password');
    };
    input.addEventListener('blur', () => {
      if (input.value !== '' || touched.has(name)) {
        touched.add(name);
        validate(name);
      }
    });
    input.addEventListener(input.tagName === 'SELECT' ? 'change' : 'input', live);
  });

  // Құпиясөз күші мен талаптар тізімі
  const meter = form.querySelector('.meter');
  const meterLabel = document.getElementById('password-strength');
  const LEVELS = ['Күші: —', 'Әлсіз', 'Орташа', 'Жақсы', 'Күшті'];
  function updateStrength() {
    const pw = val('password');
    const c = checks(pw);
    form.querySelectorAll('.rule').forEach((li) => {
      const ok = !!c[li.dataset.rule];
      li.classList.toggle('rule--ok', ok);
      li.querySelector('.rule__state').textContent = ok ? ' — орындалды' : ' — орындалмаған';
    });
    const level = pw ? Object.values(c).filter(Boolean).length : 0;
    meter.dataset.level = String(level);
    meterLabel.textContent = pw ? LEVELS[Math.max(level, 1)] : LEVELS[0];
  }
  el('password').addEventListener('input', updateStrength);
  updateStrength();

  // Жіберу
  const submit = document.getElementById('register-submit');
  form.addEventListener('submit', (event) => {
    let first = null;
    ORDER.forEach((name) => {
      touched.add(name);
      if (validate(name) && !first) first = el(name);
    });
    if (first) {
      event.preventDefault();
      first.focus();
      return;
    }
    submit.disabled = true;
    submit.classList.add('is-loading');
    submit.setAttribute('aria-busy', 'true');
    submit.querySelector('.btn__text').textContent = 'Тіркелуде…';
  });

  // Сервер қате қайтарса — бірінші қате өріске фокус
  const firstInvalid = form.querySelector('[aria-invalid="true"]');
  if (firstInvalid) {
    ORDER.forEach((name) => touched.add(name));
    firstInvalid.focus();
  }
})();
