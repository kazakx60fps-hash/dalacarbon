/* DalaCarbon AI — барлық беттерге ортақ: құпиясөзді көрсету/жасыру және хабарламалар. */
(() => {
  'use strict';

  // Құпиясөзді көрсету / жасыру
  document.querySelectorAll('.pw-toggle').forEach((btn) => {
    btn.addEventListener('click', () => {
      const input = document.getElementById(btn.getAttribute('aria-controls'));
      const show = input.type === 'password';
      input.type = show ? 'text' : 'password';
      btn.setAttribute('aria-pressed', String(show));
      const label = show ? btn.dataset.labelHide : btn.dataset.labelShow;
      btn.setAttribute('aria-label', label);
      btn.title = label;
      input.focus({ preventScroll: true });
    });
  });

  // data-notice бар батырмалар (Google, Apple, Telegram…) — әзірге хабарлама көрсетеді
  const notice = document.getElementById('notice');
  if (notice) {
    document.querySelectorAll('[data-notice]').forEach((btn) => {
      btn.addEventListener('click', () => {
        notice.textContent = btn.dataset.notice;
        notice.hidden = false;
      });
    });
  }

  // Жіберу кезінде батырманы бұғаттау (екі рет басылмасын)
  window.DalaCarbon = {
    setLoading(button, text) {
      button.disabled = true;
      button.classList.add('is-loading');
      button.setAttribute('aria-busy', 'true');
      button.querySelector('.btn__text').textContent = text;
    },
  };
})();
