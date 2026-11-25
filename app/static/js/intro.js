/* DalaCarbon AI — кіру бетіндегі интро: спутник → Жер → нысана → пилоттық алқап.
 * Кезеңдер CSS-те (data-stage), мұнда тек уақыт пен «өткізу / қайта көру» батырмасы. */
(() => {
  'use strict';

  const intro = document.getElementById('intro');
  const toggle = document.getElementById('intro-toggle');
  if (!intro || !toggle) return;

  const SCHEDULE = [[2, 1600], [3, 3500], [4, 5400]]; // [кезең, мс]
  let timers = [];

  const clear = () => { timers.forEach(clearTimeout); timers = []; };

  function setStage(stage, instant) {
    if (instant) {
      intro.classList.add('is-instant');
      intro.dataset.stage = String(stage);
      void intro.offsetWidth; // стильді бірден қолдану
      requestAnimationFrame(() => intro.classList.remove('is-instant'));
    } else {
      intro.dataset.stage = String(stage);
    }
  }

  function showReplay(done) {
    toggle.textContent = done ? 'Қайта көру' : 'Анимацияны өткізу';
    toggle.dataset.mode = done ? 'replay' : 'skip';
  }

  function play() {
    clear();
    setStage(1, true);
    showReplay(false);
    SCHEDULE.forEach(([stage, at]) => {
      timers.push(setTimeout(() => {
        setStage(stage, false);
        if (stage === 4) showReplay(true);
      }, at));
    });
  }

  function skip() {
    clear();
    setStage(4, true);
    showReplay(true);
  }

  toggle.addEventListener('click', () => (toggle.dataset.mode === 'replay' ? play() : skip()));

  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (reduce) skip(); else play();
})();
