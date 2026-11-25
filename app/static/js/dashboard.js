/* DalaCarbon AI — басқару тақтасы: мәзірді жию және белсенді бөлімді белгілеу. */
(() => {
  'use strict';

  const root = document.getElementById('dash2');
  const collapse = document.getElementById('side-collapse');
  if (!root || !collapse) return;

  const KEY = 'dalacarbon.sideCollapsed';
  function setCollapsed(on) {
    root.classList.toggle('is-collapsed', on);
    collapse.setAttribute('aria-expanded', String(!on));
    const label = on ? 'Мәзірді ашу' : 'Мәзірді жию';
    collapse.setAttribute('aria-label', label);
    collapse.title = label;
  }
  setCollapsed(localStorage.getItem(KEY) === '1');
  collapse.addEventListener('click', () => {
    const on = !root.classList.contains('is-collapsed');
    setCollapsed(on);
    localStorage.setItem(KEY, on ? '1' : '0');
  });

  // Мәзірдегі белсенді пункт: басқанда және бөлімдер экранға кіргенде
  const links = [...document.querySelectorAll('.side__nav .side__link')];
  const activate = (hash) => links.forEach((a) => {
    const on = a.getAttribute('href') === hash;
    a.classList.toggle('is-active', on);
    if (on) a.setAttribute('aria-current', 'true'); else a.removeAttribute('aria-current');
  });
  links.forEach((a) => a.addEventListener('click', () => activate(a.getAttribute('href'))));

  const sections = ['#ndvi', '#income'].map((h) => document.querySelector(h)).filter(Boolean);
  if ('IntersectionObserver' in window && sections.length) {
    const io = new IntersectionObserver((entries) => {
      const seen = entries.filter((e) => e.isIntersecting).sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
      if (seen && window.scrollY > 40) activate('#' + seen.target.id);
      else if (window.scrollY <= 40) activate('#overview');
    }, { threshold: [0.6] });
    sections.forEach((s) => io.observe(s));
  }
})();
