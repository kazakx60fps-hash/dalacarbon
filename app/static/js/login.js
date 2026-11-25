/* DalaCarbon AI — кіру формасы: бос өрістерді браузерде тексеру.
 * Логин мен құпиясөздің дұрыстығын тек сервер тексереді. */
(() => {
  'use strict';

  const form = document.getElementById('login-form');
  if (!form) return;

  const MSG = {
    login: 'Логин немесе email өрісін толтырыңыз',
    password: 'Құпиясөзді енгізіңіз',
  };

  function setError(name, message) {
    const input = form.elements.namedItem(name);
    const line = document.getElementById(`${name}-error`);
    input.setAttribute('aria-invalid', message ? 'true' : 'false');
    line.querySelector('.field__error-text').textContent = message;
    line.hidden = !message;
    input.closest('.field').classList.toggle('field--invalid', !!message);
  }

  const validate = (name) => {
    const value = form.elements.namedItem(name).value;
    const message = (name === 'login' ? value.trim() : value) ? '' : MSG[name];
    setError(name, message);
    return message;
  };

  Object.keys(MSG).forEach((name) => {
    const input = form.elements.namedItem(name);
    input.addEventListener('input', () => {
      if (input.getAttribute('aria-invalid') === 'true') validate(name);
    });
  });

  const submit = document.getElementById('login-submit');
  form.addEventListener('submit', (event) => {
    let first = null;
    Object.keys(MSG).forEach((name) => {
      if (validate(name) && !first) first = form.elements.namedItem(name);
    });
    if (first) {
      event.preventDefault();
      first.focus();
      return;
    }
    window.DalaCarbon.setLoading(submit, 'Тексерілуде…');
  });
})();
