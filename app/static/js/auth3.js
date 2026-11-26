/* DalaCarbon AI — «V7» кіру картасының анимациясы.
 * Бет ашылғанда: логотип (екі үшбұрыш қосылады) → жарқыраған шар → форма жолма-жол шығады.
 * «Тіркелу» / «Кіру» сілтемесі: форма ериді → логотип → шар → келесі бет (ол шардан бастап ашылады). */
(() => {
  'use strict';

  const card = document.querySelector('[data-v7]');
  if (!card) return;

  const KEY = 'dalacarbon.authSwap';
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const body = card.querySelector('.v7__body');

  // Анимацияланатын жолдар: картаның тікелей балалары және форманың балалары
  const items = [];
  [...body.children].forEach((el) => {
    if (el.matches('form')) [...el.children].forEach((c) => { if (c.type !== 'hidden') items.push(c); });
    else items.push(el);
  });
  items.forEach((el, i) => {
    el.setAttribute('data-v7-item', '');
    el.style.setProperty('--i', String(i));
    el.style.setProperty('--n', String(items.length - i));
  });

  const timers = [];
  const later = (fn, ms) => timers.push(setTimeout(fn, ms));
  const phase = (p) => { card.dataset.phase = p; };
  const focusFirst = () => {
    const target = card.querySelector('[autofocus]') || card.querySelector('[aria-invalid="true"]');
    if (target && document.activeElement !== target) target.focus({ preventScroll: true });
  };

  let fromSwap = false;
  try { fromSwap = sessionStorage.getItem(KEY) === '1'; sessionStorage.removeItem(KEY); } catch { /* жеке режим */ }

  // Бастапқы «hidden» күйінің стилін бірден есептетеміз, сонда келесі кезеңге ауысу анимацияланады.
  // (requestAnimationFrame қолданбаймыз: жасырын қойындыда ол таймерлерден кеш орындалады.)
  void card.offsetWidth;

  if (reduce || card.hasAttribute('data-quick')) {
    phase('in');
    focusFirst();
  } else if (fromSwap) {
    // Алдыңғы бет шармен аяқталды — осы бет шардан басталады
    phase('orb');
    later(() => { phase('in'); later(focusFirst, 500); }, 420);
  } else {
    phase('logo');
    later(() => phase('orb'), 700);
    later(() => { phase('in'); later(focusFirst, 500); }, 1300);
  }

  // Кіру ↔ Тіркелу ауысуы
  document.querySelectorAll('[data-swap]').forEach((link) => {
    link.addEventListener('click', (e) => {
      if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
      e.preventDefault();
      timers.forEach(clearTimeout);
      const go = () => {
        try { sessionStorage.setItem(KEY, '1'); } catch { /* жеке режим */ }
        window.location.href = link.href;
      };
      if (reduce) { go(); return; }
      if (document.activeElement) document.activeElement.blur();
      phase('out');
      later(() => phase('logo'), 360);
      later(() => phase('orb'), 820);
      later(go, 1250);
    });
  });

  // «Артқа» батырмасымен кэштен қайтқанда (bfcache) — форманы бірден көрсету
  window.addEventListener('pageshow', (e) => { if (e.persisted) { timers.forEach(clearTimeout); phase('in'); } });
})();
