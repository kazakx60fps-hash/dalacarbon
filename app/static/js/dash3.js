/* DalaCarbon AI — «шыны» басқару тақтасы: беттер, анимациялар және барлық батырмалар. */
(() => {
  'use strict';

  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
  const root = $('#d3');
  if (!root) return;

  const DATA = JSON.parse($('#dash-data').textContent);
  const html = document.documentElement;
  const store = {
    get(k, d = null) { try { const v = localStorage.getItem('dalacarbon.' + k); return v === null ? d : JSON.parse(v); } catch { return d; } },
    set(k, v) { try { localStorage.setItem('dalacarbon.' + k, JSON.stringify(v)); } catch { /* жеке режим */ } },
  };
  const nextFrame = (fn) => requestAnimationFrame(() => requestAnimationFrame(fn));
  const fmtInt = (n) => Math.round(n).toLocaleString('ru-RU').replace(/ /g, ' ');
  const fmtNum = (n, d = 1) => n.toLocaleString('ru-RU', { maximumFractionDigits: d }).replace(/ /g, ' ');
  const SVGNS = 'http://www.w3.org/2000/svg';
  const svgEl = (tag, attrs = {}) => {
    const el = document.createElementNS(SVGNS, tag);
    Object.entries(attrs).forEach(([k, v]) => el.setAttribute(k, v));
    return el;
  };

  /* ── Баптаулар: анимация және жинақы мәзір ── */
  if (store.get('motion', true) === false) html.classList.add('no-motion');
  const motionOn = () => !html.classList.contains('no-motion') && !matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ── Toast ── */
  const toasts = $('#toasts');
  const checkIcon = '<svg class="ico" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>';
  const errIcon = '<svg class="ico" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="8.5"/><path d="M12 8v5M12 16v.2"/></svg>';
  function toast(message, kind = 'ok') {
    const t = document.createElement('div');
    t.className = 'toast3' + (kind === 'err' ? ' toast3--err' : '');
    t.innerHTML = kind === 'err' ? errIcon : checkIcon;
    const span = document.createElement('span');
    span.textContent = message;
    t.append(span);
    toasts.append(t);
    setTimeout(() => { t.classList.add('is-out'); t.addEventListener('animationend', () => t.remove(), { once: true }); }, 3400);
  }

  /* ── Айналмалы сандар (одометр) ── */
  function formatOdo(value, format) {
    if (format === 'money') return '$' + fmtInt(value);
    if (format === 'pct') return value.toLocaleString('ru-RU', { minimumFractionDigits: 1, maximumFractionDigits: 1 }) + '%';
    if (format === 'pct0') return Math.round(value) + '%';
    return fmtInt(value);
  }
  function runOdo(el, delay = 0) {
    const text = formatOdo(parseFloat(el.dataset.value), el.dataset.format);
    el.setAttribute('aria-label', text);
    if (!motionOn()) { el.textContent = text; return; }
    el.textContent = '';
    const strips = [];
    [...text].forEach((ch, i) => {
      if (/\d/.test(ch)) {
        const box = document.createElement('span');
        box.className = 'odo__d';
        box.setAttribute('aria-hidden', 'true');
        const strip = document.createElement('span');
        strip.className = 'odo__strip';
        for (let k = 0; k < 20; k += 1) { const s = document.createElement('span'); s.textContent = k % 10; strip.append(s); }
        strip.style.setProperty('--dd', delay + i * 70 + 'ms');
        box.append(strip);
        el.append(box);
        strips.push([strip, 10 + Number(ch)]);
      } else {
        const s = document.createElement('span');
        s.className = 'odo__s';
        s.setAttribute('aria-hidden', 'true');
        s.textContent = ch;
        el.append(s);
      }
    });
    nextFrame(() => strips.forEach(([strip, idx]) => { strip.style.transform = `translateY(-${idx * 1.15}em)`; }));
  }

  /* ── Кіру анимациясы ── */
  function reveal(view) {
    $$('[data-reveal]', view).forEach((el, i) => {
      el.classList.remove('rv-done', 'rv-run', 'is-shown');
      void el.offsetWidth;
      el.style.setProperty('--d', Math.min(i * 70, 700) + 'ms');
      el.classList.add('rv-run', 'is-shown');
    });
    $$('.odo', view).forEach((el, i) => runOdo(el, 250 + i * 40));
    const ring = $('[data-ring]', view);
    if (ring) { ring.style.strokeDasharray = '0 100'; nextFrame(() => { ring.style.strokeDasharray = `${ring.dataset.ring} 100`; }); }
    $$('[data-bar]', view).forEach((b) => { b.style.width = '0'; nextFrame(() => { b.style.width = b.dataset.bar + '%'; }); });
  }
  document.addEventListener('animationend', (e) => {
    const el = e.target;
    if (e.animationName === 'reveal' && el.hasAttribute('data-reveal')) { el.classList.remove('rv-run'); el.classList.add('rv-done'); }
  });

  /* ── Мәзір: белсенді пункт пен жылжымалы фон ── */
  const nav = $('#d3-nav');
  const navPill = $('.d3-nav__pill', nav);
  function placeNavPill() {
    const link = $('.d3-nav__link.is-active', nav);
    if (!link) { navPill.style.opacity = '0'; return; }
    navPill.style.opacity = '1';
    navPill.style.height = link.offsetHeight + 'px';
    navPill.style.transform = `translateY(${link.offsetTop}px)`;
  }

  /* ── Беттер (hash арқылы, «Артқа» батырмасы да жұмыс істейді) ── */
  const views = $$('.d3-view');
  const main = $('#d3-main');
  let current = null;
  const onShow = {};

  function show(name, { focus = false } = {}) {
    const next = views.find((v) => v.dataset.view === name) || views[0];
    if (next === current) { reveal(next); return; }
    const prev = current;
    current = next;
    $$('.d3-nav__link', nav).forEach((a) => {
      const on = a.dataset.go === next.dataset.view;
      a.classList.toggle('is-active', on);
      if (on) a.setAttribute('aria-current', 'page'); else a.removeAttribute('aria-current');
    });
    placeNavPill();
    document.title = ($('h1', next)?.textContent.trim() || 'Басқару тақтасы') + ' — DalaCarbon AI';
    const enter = () => {
      // Барлық басқа беттерді жасырамыз (сілтеме #inbox сияқты тікелей ашылса да, «Шолу» көрінбей қалсын)
      views.forEach((v) => { if (v !== next) { v.hidden = true; v.classList.remove('is-leaving'); } });
      next.hidden = false;
      main.scrollTo({ top: 0 });
      if (window.innerWidth <= 900) window.scrollTo({ top: 0 });
      reveal(next);
      (onShow[next.dataset.view] || (() => {}))();
      if (focus) main.focus({ preventScroll: true });
    };
    if (prev && motionOn()) { prev.classList.add('is-leaving'); setTimeout(enter, 200); } else enter();
    closeMenu();
  }
  function go(name) {
    if (location.hash !== '#' + name) location.hash = name; else show(name);
  }
  window.addEventListener('hashchange', () => show(location.hash.slice(1), { focus: true }));

  /* ── Жиналмалы мәзір ── */
  const collapseBtn = $('#side-collapse');
  const compactToggle = $('[data-pref="compact"]');
  function setCollapsed(on, save = true) {
    root.classList.toggle('is-collapsed', on);
    const label = on ? 'Мәзірді ашу' : 'Мәзірді жию';
    collapseBtn.setAttribute('aria-expanded', String(!on));
    collapseBtn.setAttribute('aria-label', label);
    collapseBtn.title = label;
    if (compactToggle) compactToggle.checked = on;
    if (save) store.set('sideCollapsed', on);
    setTimeout(() => { placeNavPill(); redrawCharts(); }, 480);
  }
  setCollapsed(store.get('sideCollapsed', false) === true, false);
  collapseBtn.addEventListener('click', () => setCollapsed(!root.classList.contains('is-collapsed')));

  /* ── Телефондағы мәзір ── */
  const openBtn = $('#side-open');
  const scrim = $('#side-scrim');
  function openMenu() { root.classList.add('is-menu'); scrim.hidden = false; openBtn.setAttribute('aria-expanded', 'true'); setTimeout(placeNavPill, 60); }
  function closeMenu() { if (!root.classList.contains('is-menu')) return; root.classList.remove('is-menu'); scrim.hidden = true; openBtn.setAttribute('aria-expanded', 'false'); }
  openBtn.addEventListener('click', () => (root.classList.contains('is-menu') ? closeMenu() : openMenu()));
  scrim.addEventListener('click', closeMenu);

  /* ── Сегменттелген батырмалар үшін жылжымалы фон ── */
  function placePill(group, pill, activeSel) {
    const btn = $(activeSel, group);
    if (!btn || !btn.offsetWidth) return;
    pill.style.width = btn.offsetWidth + 'px';
    pill.style.transform = `translateX(${btn.offsetLeft}px)`;
  }

  /* ── График: көміртегі жинақталуы ── */
  const charts = [];
  function makeChart(box) {
    const chart = { box, range: Number(box.dataset.chart), panel: box.closest('.panel3') };
    const tip = document.createElement('div');
    tip.className = 'chart3__tip';
    box.append(tip);

    chart.render = (animate = true) => {
      const w = box.clientWidth;
      const h = box.clientHeight;
      if (!w) return;
      box.querySelector('svg')?.remove();
      const pts = DATA.series.slice(-chart.range);
      const pad = { l: 42, r: 12, t: 14, b: 28 };
      const max = Math.max(...pts.flatMap((p) => [p.measured, p.forecast]));
      // «Әдемі» қадам: 1, 2, 2.5, 5 × 10ⁿ — осьте 0, 150, 300… сияқты сандар шығады
      const raw = (max * 1.08) / 4 || 1;
      const mag = Math.pow(10, Math.floor(Math.log10(raw)));
      const tick = [1, 2, 2.5, 5, 10].map((m) => m * mag).find((v) => v >= raw);
      const yMax = tick * 4;
      const x = (i) => pad.l + (pts.length === 1 ? 0 : (i * (w - pad.l - pad.r)) / (pts.length - 1));
      const y = (v) => pad.t + (1 - v / yMax) * (h - pad.t - pad.b);
      const id = 'c' + Math.random().toString(36).slice(2, 8);

      const svg = svgEl('svg', { viewBox: `0 0 ${w} ${h}`, role: 'img', 'aria-label': `Соңғы ${pts.length} айдағы секвестрация графигі` });
      const defs = svgEl('defs');
      const grad = svgEl('linearGradient', { id: id + 'g', x1: 0, y1: 0, x2: 0, y2: 1 });
      grad.append(svgEl('stop', { offset: '0%', 'stop-color': '#e9775a', 'stop-opacity': '.38' }), svgEl('stop', { offset: '100%', 'stop-color': '#e9775a', 'stop-opacity': '0' }));
      const clip = svgEl('clipPath', { id: id + 'k' });
      const clipRect = svgEl('rect', { x: 0, y: 0, width: animate && motionOn() ? 0 : w, height: h });
      clip.append(clipRect);
      defs.append(grad, clip);
      svg.append(defs);

      const grid = svgEl('g', { class: 'grid' });
      for (let k = 0; k <= 4; k += 1) {
        const v = (yMax * k) / 4;
        grid.append(svgEl('line', { x1: pad.l, x2: w - pad.r, y1: y(v), y2: y(v) }));
        const t = svgEl('text', { x: pad.l - 10, y: y(v) + 4, 'text-anchor': 'end', class: 'ylab' });
        t.textContent = fmtInt(v);
        grid.append(t);
      }
      pts.forEach((p, i) => {
        const t = svgEl('text', { x: x(i), y: h - 6, 'text-anchor': 'middle', class: 'xlab' });
        t.textContent = p.label;
        grid.append(t);
      });
      svg.append(grid);

      // Тегіс сызық (Catmull-Rom → Безье)
      const smooth = (vals) => vals.map((v, i) => {
        if (i === 0) return `M${x(0)},${y(v)}`;
        const p0 = vals[i - 2] ?? vals[i - 1]; const p1 = vals[i - 1]; const p3 = vals[i + 1] ?? v;
        const c1x = x(i - 1) + (x(i) - x(i - 2 < 0 ? 0 : i - 2)) / 6; const c1y = y(p1) + (y(v) - y(p0)) / 6;
        const c2x = x(i) - (x(i + 1 > vals.length - 1 ? i : i + 1) - x(i - 1)) / 6; const c2y = y(v) - (y(p3) - y(p1)) / 6;
        return `C${c1x},${c1y} ${c2x},${c2y} ${x(i)},${y(v)}`;
      }).join(' ');
      const measured = pts.map((p) => p.measured);
      const lineD = smooth(measured);
      const body = svgEl('g', { 'clip-path': `url(#${id}k)` });
      body.append(
        svgEl('path', { d: `${lineD} L${x(pts.length - 1)},${y(0)} L${x(0)},${y(0)} Z`, fill: `url(#${id}g)` }),
        svgEl('path', { d: smooth(pts.map((p) => p.forecast)), class: 'l-forecast' }),
        svgEl('path', { d: lineD, class: 'l-measured' }),
      );
      const dots = pts.map((p, i) => { const c = svgEl('circle', { cx: x(i), cy: y(p.measured), r: 3.5, class: 'pt' }); body.append(c); return c; });
      const hover = svgEl('line', { class: 'hover-line', y1: pad.t, y2: h - pad.b, x1: -10, x2: -10 });
      svg.append(hover, body);
      box.prepend(svg);

      if (animate && motionOn()) {
        const t0 = performance.now();
        const dur = 1100;
        const step = (now) => {
          const k = Math.min((now - t0) / dur, 1);
          clipRect.setAttribute('width', w * (1 - Math.pow(1 - k, 3)));
          if (k < 1) requestAnimationFrame(step);
        };
        requestAnimationFrame(step);
      }

      // Түсіндірме (tooltip)
      const near = (evt) => {
        const r = svg.getBoundingClientRect();
        const px = ((evt.clientX - r.left) / r.width) * w;
        let best = 0;
        pts.forEach((_, i) => { if (Math.abs(x(i) - px) < Math.abs(x(best) - px)) best = i; });
        return best;
      };
      svg.addEventListener('pointermove', (evt) => {
        const i = near(evt);
        const p = pts[i];
        hover.setAttribute('x1', x(i)); hover.setAttribute('x2', x(i));
        dots.forEach((d, k) => d.setAttribute('r', k === i ? 6 : 3.5));
        const diff = p.forecast ? Math.round(((p.measured - p.forecast) / p.forecast) * 100) : 0;
        tip.innerHTML = '';
        const b = document.createElement('b'); b.textContent = p.label;
        tip.append(b, document.createElement('br'), `Өлшенген: ${fmtInt(p.measured)} т`, document.createElement('br'),
          `Болжам: ${fmtInt(p.forecast)} т (${diff >= 0 ? '+' : ''}${diff}%)`);
        tip.style.left = (x(i) / w) * 100 + '%';
        tip.style.top = (y(p.measured) / h) * 100 + '%';
        tip.classList.add('is-on');
      });
      svg.addEventListener('pointerleave', () => { tip.classList.remove('is-on'); hover.setAttribute('x1', -10); hover.setAttribute('x2', -10); dots.forEach((d) => d.setAttribute('r', 3.5)); });

      const total = measured.reduce((a, b) => a + b, 0);
      const fc = pts.reduce((a, p) => a + p.forecast, 0);
      const delta = fc ? ((total - fc) / fc) * 100 : 0;
      const sub = $('[data-chart-sub]', chart.panel);
      if (sub) sub.textContent = `Соңғы ${pts.length} айда ${fmtInt(total)} т CO₂e · болжамнан ${delta >= 0 ? '+' : ''}${fmtNum(delta)}%`;
    };

    const seg = $('.seg', chart.panel);
    if (seg) {
      const pill = $('.seg__pill', seg);
      chart.placePill = () => placePill(seg, pill, '.seg__btn.is-active');
      $$('.seg__btn', seg).forEach((btn) => btn.addEventListener('click', () => {
        if (btn.classList.contains('is-active')) return;
        $$('.seg__btn', seg).forEach((b) => { const on = b === btn; b.classList.toggle('is-active', on); b.setAttribute('aria-selected', String(on)); });
        chart.range = Number(btn.dataset.range);
        chart.placePill();
        chart.render(true);
      }));
    }
    charts.push(chart);
    return chart;
  }
  $$('[data-chart]').forEach(makeChart);
  function drawChartsIn(view, animate = true) {
    charts.filter((c) => view.contains(c.box)).forEach((c) => { c.placePill?.(); c.render(animate); });
  }
  function redrawCharts() { if (current) drawChartsIn(current, false); }
  let resizeTimer;
  window.addEventListener('resize', () => {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(() => { placeNavPill(); redrawCharts(); placeWeekPill(); }, 150);
  });

  /* ── Сақина диаграмма: учаскелер бойынша ── */
  const donut = $('[data-donut]');
  const COLORS = ['#d4553c', '#ec9a7c', '#2a1a14', '#d79a2b'];
  function buildDonut() {
    if (!donut) return;
    const svg = $('svg', donut);
    const legend = $('[data-donut-legend]');
    const valueEl = $('[data-donut-value]');
    const labelEl = $('[data-donut-label]');
    const total = DATA.split.reduce((a, s) => a + s.tonnes, 0);
    svg.innerHTML = '';
    legend.innerHTML = '';
    svg.append(svgEl('circle', { cx: 80, cy: 80, r: 62, fill: 'none', stroke: 'rgba(255,255,255,.45)', 'stroke-width': 20 }));
    let offset = 0;
    const gap = 3;
    const arcs = DATA.split.map((s, i) => {
      const pct = (s.tonnes / total) * 100;
      const arc = svgEl('circle', { cx: 80, cy: 80, r: 62, class: 'seg-arc', pathLength: 100, stroke: COLORS[i % COLORS.length], tabindex: 0,
        'stroke-dasharray': '0 100', 'stroke-dashoffset': -offset, role: 'img', 'aria-label': `${s.name}: ${fmtInt(s.tonnes)} т` });
      const target = `${Math.max(pct - gap, 0.5)} ${100 - Math.max(pct - gap, 0.5)}`;
      offset += pct;
      svg.append(arc);
      const li = document.createElement('li');
      const span = document.createElement('span');
      const dot = document.createElement('i'); dot.className = 'dot3'; dot.style.background = COLORS[i % COLORS.length];
      span.append(dot, s.name);
      const strong = document.createElement('strong'); strong.textContent = `${fmtInt(s.tonnes)} т`;
      li.append(span, strong);
      legend.append(li);
      const hot = (on) => {
        donut.classList.toggle('has-hot', on);
        arc.classList.toggle('is-hot', on); li.classList.toggle('is-hot', on);
        valueEl.textContent = on ? `${Math.round(pct)}%` : `${fmtInt(total)} т`;
        labelEl.textContent = on ? `${s.name} · ${fmtInt(s.tonnes)} т` : 'барлығы';
      };
      [arc, li].forEach((el) => {
        el.addEventListener('pointerenter', () => hot(true));
        el.addEventListener('pointerleave', () => hot(false));
      });
      arc.addEventListener('focus', () => hot(true));
      arc.addEventListener('blur', () => hot(false));
      return [arc, target];
    });
    nextFrame(() => arcs.forEach(([arc, target], i) => setTimeout(() => arc.setAttribute('stroke-dasharray', target), i * 120)));
  }

  /* ── Апталық күнтізбе ── */
  const week = $('.week');
  const weekPill = week && $('.week__pill', week);
  function placeWeekPill() { if (week) placePill(week, weekPill, '.week__day.is-active'); }
  const pinIcon = '<svg class="ico" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 21s6.5-6 6.5-11a6.5 6.5 0 0 0-13 0C5.5 15 12 21 12 21z"/><circle cx="12" cy="10" r="2.3"/></svg>';
  const weekdayOf = (iso) => (new Date(iso + 'T00:00:00').getDay() + 6) % 7;
  function renderEvents(list, iso) {
    list.innerHTML = '';
    const items = DATA.events[iso] || [];
    if (!items.length) {
      const li = document.createElement('li'); li.className = 'events__empty'; li.textContent = 'Бұл күні жоспар жоқ'; list.append(li);
      return 0;
    }
    items.forEach((e, i) => {
      const li = document.createElement('li');
      li.className = `event event--${e.kind}`;
      li.style.setProperty('--d', i * 70 + 'ms');
      const time = document.createElement('time'); time.textContent = e.time;
      const span = document.createElement('span');
      const strong = document.createElement('strong'); strong.textContent = e.title;
      const small = document.createElement('small'); small.innerHTML = pinIcon; small.append(e.place);
      span.append(strong, small);
      li.append(time, span);
      list.append(li);
    });
    return items.length;
  }
  if (week) {
    $$('.week__day', week).forEach((btn) => btn.addEventListener('click', () => {
      $$('.week__day', week).forEach((b) => { const on = b === btn; b.classList.toggle('is-active', on); b.setAttribute('aria-selected', String(on)); });
      placeWeekPill();
      const iso = btn.dataset.date;
      const d = new Date(iso + 'T00:00:00');
      const count = renderEvents($('[data-events]'), iso);
      $('[data-cal-day]').textContent = String(d.getDate()).padStart(2, '0');
      $('[data-cal-weekday]').textContent = DATA.weekdays[weekdayOf(iso)];
      $('[data-cal-month]').textContent = `${DATA.months[d.getMonth()]} ${d.getFullYear()}`;
      $('[data-cal-count]').textContent = count;
    }));
  }

  /* ── Ай кестесі ── */
  function buildMonth() {
    const grid = $('[data-month]');
    if (!grid) return;
    grid.innerHTML = '';
    const today = new Date(DATA.today + 'T00:00:00');
    const first = new Date(today.getFullYear(), today.getMonth(), 1);
    const days = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();
    DATA.weekdaysShort.forEach((w) => { const s = document.createElement('span'); s.className = 'month3__wd'; s.textContent = w; grid.append(s); });
    for (let k = 0; k < (first.getDay() + 6) % 7; k += 1) { const b = document.createElement('span'); b.className = 'month3__blank'; grid.append(b); }
    const pick = (cell, iso) => {
      $$('.month3__cell', grid).forEach((c) => { c.classList.toggle('is-active', c === cell); c.setAttribute('aria-selected', String(c === cell)); });
      const d = new Date(iso + 'T00:00:00');
      $('[data-sched-title]').textContent = `${DATA.weekdays[weekdayOf(iso)]}, ${d.getDate()} ${DATA.months[d.getMonth()].toLowerCase()}`;
      renderEvents($('[data-sched-events]'), iso);
    };
    for (let day = 1; day <= days; day += 1) {
      const iso = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
      const cell = document.createElement('button');
      cell.type = 'button';
      cell.className = 'month3__cell' + (iso === DATA.today ? ' is-today' : '');
      cell.setAttribute('role', 'gridcell');
      cell.style.setProperty('--d', day * 12 + 'ms');
      const n = (DATA.events[iso] || []).length;
      cell.setAttribute('aria-label', `${day} ${DATA.months[today.getMonth()].toLowerCase()}, ${n} оқиға`);
      const num = document.createElement('span'); num.textContent = day;
      const dots = document.createElement('span'); dots.className = 'month3__dots';
      for (let k = 0; k < n; k += 1) dots.append(document.createElement('i'));
      cell.append(num, dots);
      cell.addEventListener('click', () => pick(cell, iso));
      grid.append(cell);
      if (iso === DATA.today) pick(cell, iso);
    }
  }

  /* ── Беттер ашылғанда іске қосылатындар ── */
  onShow.overview = () => { drawChartsIn(current); buildDonut(); placeWeekPill(); };
  onShow.analytics = () => drawChartsIn(current);
  onShow.schedule = buildMonth;

  /* ── Модаль терезелер ── */
  function openDialog(id) {
    const d = document.getElementById(id);
    if (!d || d.open) return;
    closeMenu();
    $('#notif-pop').hidden = true;
    d.showModal();
    if (id === 'palette') resetPalette();
    if (id === 'parcel-modal') setTimeout(() => $('input[name="name"]', d).focus(), 60);
  }
  function closeDialog(d, after) {
    if (!d.open) { after?.(); return; }
    if (!motionOn()) { d.close(); after?.(); return; }
    d.classList.add('is-closing');
    d.addEventListener('animationend', () => { d.classList.remove('is-closing'); d.close(); after?.(); }, { once: true });
  }
  $$('dialog').forEach((d) => {
    d.addEventListener('cancel', (e) => { e.preventDefault(); closeDialog(d); });
    d.addEventListener('click', (e) => { if (e.target === d) closeDialog(d); });
  });

  /* ── Жалпы батырмалар: data-go / data-open / data-close ── */
  document.addEventListener('click', (e) => {
    const el = e.target.closest('[data-go], [data-open], [data-close], [data-sat], [data-report]');
    if (!el) return;
    if (el.closest('[data-palette-list]')) return; // палитраның өз өңдегіші бар
    const dlg = el.closest('dialog');
    if (el.hasAttribute('data-report')) { toast('Есеп дайындалуда — CSV файл жүктеледі'); return; }
    if (el.hasAttribute('data-sat')) { e.preventDefault(); refreshSatellite(); return; }
    e.preventDefault();
    if (el.hasAttribute('data-close') && dlg) {
      closeDialog(dlg, () => { if (el.dataset.go) go(el.dataset.go); });
      return;
    }
    if (el.dataset.open) openDialog(el.dataset.open);
    else if (el.dataset.go) go(el.dataset.go);
  });

  /* ── NDVI картасы (Leaflet): Қазақстан шекарасымен шектелген ── */
  const NDVI = DATA.ndvi;
  const KZ_BOUNDS = [[40.5, 46.5], [55.5, 87.3]]; // оңтүстік-батыс, солтүстік-шығыс
  const mapBox = $('[data-lmap]');
  const statusEl = $('[data-ndvi-status]');
  const opacityInput = $('[data-ndvi-opacity]');
  const opacityOut = $('[data-ndvi-opacity-out]');
  let map = null;
  let ndviLayer = null;
  let season = NDVI.seasons[0];
  let baseKey = 'sat';
  const bases = {};
  let failed = 0;
  const providerName = () => (NDVI.provider === 'sentinel' ? 'Sentinel-2' : 'MODIS');

  function setStatus(text, isError = false) {
    if (!statusEl) return;
    statusEl.hidden = !text;
    statusEl.textContent = text || '';
    statusEl.classList.toggle('is-error', isError);
  }
  // Leaflet «loading» / «load» оқиғалары: көрінетін барлық тайл жүктелгенде «load» келеді
  function layerLoaded() {
    if (failed > 2) {
      setStatus(NDVI.provider === 'sentinel'
        ? 'NDVI суреттері жүктелмеді: Instance ID-ді немесе интернетті тексеріңіз'
        : 'NDVI суреттері жүктелмеді: интернет байланысын тексеріңіз', true);
    } else setStatus(null);
    failed = 0;
  }
  function makeNdviLayer() {
    const common = { bounds: KZ_BOUNDS, opacity: opacityInput.value / 100, className: 'ndvi-layer', zIndex: 5 };
    const layer = NDVI.provider === 'sentinel'
      ? L.tileLayer.wms(`https://sh.dataspace.copernicus.eu/ogc/wms/${encodeURIComponent(NDVI.instance)}`, {
        ...common, layers: NDVI.layer, format: 'image/png', transparent: true, maxcc: 20,
        time: `${season.from}/${season.to}`, maxZoom: 16,
        attribution: '© <a href="https://dataspace.copernicus.eu" target="_blank" rel="noopener">Copernicus Sentinel-2</a>',
      })
      : L.tileLayer('https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/MODIS_Terra_L3_NDVI_16Day/default/{time}/GoogleMapsCompatible_Level9/{z}/{y}/{x}.png', {
        ...common, time: season.date, maxNativeZoom: 9, maxZoom: 16,
        attribution: '<a href="https://earthdata.nasa.gov/gibs" target="_blank" rel="noopener">NASA GIBS</a> · MODIS Terra NDVI',
      });
    layer.on('loading', () => setStatus(`NDVI жүктелуде · ${providerName()} · ${season.label}`));
    layer.on('load', layerLoaded);
    layer.on('tileerror', () => { failed += 1; });
    return layer;
  }
  function swapNdvi() {
    if (!map) return;
    const old = ndviLayer;
    failed = 0;
    ndviLayer = makeNdviLayer().addTo(map);
    if (old) map.removeLayer(old);
    const warn = $('[data-ndvi-warn]');
    if (warn) warn.hidden = !season.winter;
  }
  function nearestRegion(lat, lng) {
    const km = (a, b) => {
      const r = Math.PI / 180;
      const d = Math.sin(((b[0] - a[0]) * r) / 2) ** 2
        + Math.cos(a[0] * r) * Math.cos(b[0] * r) * Math.sin(((b[1] - a[1]) * r) / 2) ** 2;
      return 12742 * Math.asin(Math.sqrt(d));
    };
    return NDVI.regions.map((reg) => ({ ...reg, km: km([lat, lng], reg.center) })).sort((a, b) => a.km - b.km)[0];
  }
  function flyToRegion(key, animate = true) {
    if (!map) return;
    const smooth = animate && motionOn();
    if (key === 'kz') { map.flyToBounds(KZ_BOUNDS, { animate: smooth, duration: 1.2 }); return; }
    const reg = NDVI.regions.find((r) => r.key === key);
    if (reg) map.flyTo(reg.center, 7, { animate: smooth, duration: 1.6 });
  }
  function initMap() {
    if (map || !mapBox) return;
    if (!window.L) { setStatus('Карта кітапханасы жүктелмеді', true); return; }
    map = L.map(mapBox, {
      center: [48.02, 66.92], zoom: 5, minZoom: 4, maxZoom: 16,
      maxBounds: L.latLngBounds(KZ_BOUNDS).pad(0.12), maxBoundsViscosity: 1.0, // шекарадан сыртқа шығармайды
      zoomSnap: 0.5, fadeAnimation: motionOn(), zoomAnimation: motionOn(),
    });
    map.attributionControl.setPrefix('<a href="https://leafletjs.com" target="_blank" rel="noopener">Leaflet</a>');
    L.control.scale({ metric: true, imperial: false }).addTo(map);
    bases.sat = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
      maxZoom: 18, attribution: 'Esri, Maxar, Earthstar Geographics' });
    bases.osm = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19, attribution: '© <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">OpenStreetMap</a>' });
    bases[baseKey].addTo(map);
    swapNdvi();

    // Қазақстан шекарасы және сыртын күңгірттейтін маска
    fetch(NDVI.border).then((r) => r.json()).then((gj) => {
      const geom = gj.features[0].geometry;
      const polys = geom.type === 'Polygon' ? [geom.coordinates] : geom.coordinates;
      const holes = polys.map((poly) => poly[0].map(([lng, lat]) => [lat, lng]));
      L.polygon([[[85, -179], [85, 179], [-85, 179], [-85, -179]], ...holes],
        { stroke: false, fillColor: '#2a1a14', fillOpacity: 0.55, interactive: false }).addTo(map);
      L.geoJSON(gj, { style: { color: '#fff8f3', weight: 2, opacity: 0.95, fill: false }, interactive: false }).addTo(map);
    }).catch(() => {});

    // Пайдаланушының облысы
    const home = NDVI.regions.find((r) => r.key === NDVI.region);
    if (home) {
      L.circleMarker(home.center, { radius: 7, color: '#fff', weight: 2.5, fillColor: '#d4553c', fillOpacity: 1 })
        .addTo(map).bindTooltip(`${home.name} · сіздің облысыңыз`, { direction: 'top', offset: [0, -6] });
      setTimeout(() => flyToRegion(home.key), motionOn() ? 500 : 0);
    }

    // Картаны басқанда: координата және жақын облыс орталығы
    map.on('click', (e) => {
      const { lat, lng } = e.latlng;
      const near = nearestRegion(lat, lng);
      const box = document.createElement('div');
      const title = document.createElement('strong');
      title.textContent = `${lat.toFixed(4)}°, ${lng.toFixed(4)}°`;
      box.append(title, document.createElement('br'), `Жақын орталық: ${near.name} (${Math.round(near.km)} км)`,
        document.createElement('br'), `${providerName()} · ${season.label}`);
      L.popup().setLatLng(e.latlng).setContent(box).openOn(map);
    });
  }

  if (mapBox) {
    $('[data-ndvi-region]').addEventListener('change', (e) => flyToRegion(e.target.value));
    const seasonSeg = $('[data-ndvi-seasons]');
    const baseSeg = $('[data-ndvi-base]');
    const pickSeg = (seg, btn) => {
      $$('.seg__btn', seg).forEach((b) => { const on = b === btn; b.classList.toggle('is-active', on); b.setAttribute('aria-selected', String(on)); });
      placePill(seg, $('.seg__pill', seg), '.seg__btn.is-active');
    };
    $$('.seg__btn', seasonSeg).forEach((btn) => btn.addEventListener('click', () => {
      pickSeg(seasonSeg, btn);
      season = NDVI.seasons.find((x) => x.key === btn.dataset.season);
      swapNdvi();
    }));
    $$('.seg__btn', baseSeg).forEach((btn) => btn.addEventListener('click', () => {
      pickSeg(baseSeg, btn);
      if (!map || btn.dataset.base === baseKey) return;
      map.removeLayer(bases[baseKey]);
      baseKey = btn.dataset.base;
      bases[baseKey].addTo(map);
    }));
    opacityInput.addEventListener('input', () => {
      opacityOut.textContent = opacityInput.value + '%';
      if (ndviLayer) ndviLayer.setOpacity(opacityInput.value / 100);
    });
  }
  onShow['ndvi-map'] = () => {
    initMap();
    $$('[data-ndvi-seasons], [data-ndvi-base]').forEach((seg) => placePill(seg, $('.seg__pill', seg), '.seg__btn.is-active'));
    setTimeout(() => { if (map) map.invalidateSize(); }, 60);
  };

  /* ── «Спутник суретін жаңарту»: NDVI картасына өтіп, қабатты қайта жүктейді ── */
  function refreshSatellite() {
    const reload = () => {
      if (!map || !ndviLayer) return;
      failed = 0;
      if (ndviLayer.setParams) ndviLayer.setParams({ _t: Date.now() }); else ndviLayer.redraw();
      toast(`NDVI қабаты қайта жүктелді · ${providerName()} · ${season.label}`);
    };
    if (!current || current.dataset.view !== 'ndvi-map') { go('ndvi-map'); setTimeout(reload, 600); } else reload();
  }

  /* ── Іздеу палитрасы (Ctrl+K) ── */
  const palette = $('#palette');
  const pInput = $('[data-palette-input]');
  const pItems = $$('[data-palette-list] li');
  const pEmpty = $('[data-palette-empty]');
  let sel = 0;
  const visibleItems = () => pItems.filter((li) => !li.hidden);
  function markSel() { visibleItems().forEach((li, i) => li.classList.toggle('is-sel', i === sel)); visibleItems()[sel]?.scrollIntoView({ block: 'nearest' }); }
  function resetPalette() { pInput.value = ''; pItems.forEach((li) => { li.hidden = false; }); pEmpty.hidden = true; sel = 0; markSel(); setTimeout(() => pInput.focus(), 30); }
  pInput.addEventListener('input', () => {
    const q = pInput.value.trim().toLocaleLowerCase('kk');
    pItems.forEach((li) => { li.hidden = q && !li.textContent.toLocaleLowerCase('kk').includes(q); });
    pEmpty.hidden = visibleItems().length > 0;
    sel = 0; markSel();
  });
  function runItem(li) {
    if (!li) return;
    closeDialog(palette, () => {
      if (li.dataset.go) go(li.dataset.go);
      else if (li.dataset.open) openDialog(li.dataset.open);
      else if (li.dataset.href) { toast('Есеп дайындалуда — CSV файл жүктеледі'); location.href = li.dataset.href; }
      else if (li.hasAttribute('data-sat')) refreshSatellite();
    });
  }
  pInput.addEventListener('keydown', (e) => {
    const items = visibleItems();
    if (e.key === 'ArrowDown') { e.preventDefault(); sel = (sel + 1) % Math.max(items.length, 1); markSel(); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); sel = (sel - 1 + items.length) % Math.max(items.length, 1); markSel(); }
    else if (e.key === 'Enter') { e.preventDefault(); runItem(items[sel]); }
  });
  pItems.forEach((li) => {
    li.addEventListener('click', () => runItem(li));
    li.addEventListener('pointermove', () => { sel = visibleItems().indexOf(li); markSel(); });
  });
  document.addEventListener('keydown', (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); palette.open ? closeDialog(palette) : openDialog('palette'); }
    if (e.key === 'Escape') { closeMenu(); closeNotif(); }
  });

  /* ── Хабарламалар (поповер) ── */
  const notifBtn = $('#notif-btn');
  const notifPop = $('#notif-pop');
  function closeNotif() { if (!notifPop.hidden) { notifPop.hidden = true; notifBtn.setAttribute('aria-expanded', 'false'); } }
  notifBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    notifPop.hidden = !notifPop.hidden;
    notifBtn.setAttribute('aria-expanded', String(!notifPop.hidden));
  });
  document.addEventListener('click', (e) => { if (!notifPop.hidden && !e.target.closest('.pop-anchor')) closeNotif(); });
  function applyNotifRead() {
    $$('.pop__item', notifPop).forEach((li) => li.classList.remove('is-unread'));
    const c = $('[data-notif-count]'); c.textContent = '0'; c.classList.add('is-zero');
    updateCounts();
  }
  $('#notif-clear').addEventListener('click', () => { store.set('notifRead', true); applyNotifRead(); toast('Хабарламалар оқылды деп белгіленді'); });

  /* ── Хабарлар ── */
  const readSet = new Set(store.get('read', []));
  const reader = $('#reader');
  function updateCounts() {
    const unread = $$('.mitem.is-unread').length;
    $$('[data-unread]').forEach((el) => {
      el.textContent = unread;
      if (el.classList.contains('count')) el.classList.toggle('is-zero', unread === 0);
    });
    const notifs = store.get('notifRead', false) ? 0 : $$('.pop__item').length;
    const todo = $('[data-todo]');
    if (todo) todo.textContent = unread + notifs;
  }
  function markRead(btn) { btn.classList.remove('is-unread'); readSet.add(btn.dataset.msg); store.set('read', [...readSet]); updateCounts(); }
  $$('.mitem').forEach((btn) => {
    if (readSet.has(btn.dataset.msg)) btn.classList.remove('is-unread');
    btn.addEventListener('click', () => {
      $$('.mitem').forEach((b) => b.classList.toggle('is-active', b === btn));
      const tpl = $(`template[data-body="${btn.dataset.msg}"]`);
      const body = document.createElement('div');
      body.className = 'reader__body';
      body.append(tpl.content.cloneNode(true));
      reader.innerHTML = '';
      reader.append(body);
      markRead(btn);
      if (window.innerWidth <= 900) reader.scrollIntoView({ behavior: motionOn() ? 'smooth' : 'auto', block: 'start' });
    });
  });
  $('[data-read-all]')?.addEventListener('click', () => { $$('.mitem.is-unread').forEach(markRead); toast('Барлық хат оқылды'); });
  if (store.get('notifRead', false)) applyNotifRead();
  updateCounts();

  /* ── Алқаптар: қосу және өшіру (PostgreSQL-ге сақталады) ── */
  const form = $('[data-parcel-form]');
  const plist = $('[data-plist]');
  const pempty = $('[data-pempty]');
  const tpl = $('[data-pcard-tpl]');
  const csrf = () => $('input[name="csrf_token"]', form).value;
  const parcels = DATA.parcels.slice();

  function updateParcelSums() {
    const sum = (k) => parcels.reduce((a, p) => a + p[k], 0);
    $('[data-sum="count"]').textContent = parcels.length;
    $('[data-sum="area"]').textContent = fmtNum(sum('area_ha'));
    $('[data-sum="tonnes"]').textContent = fmtNum(sum('tonnes'));
    $('[data-sum="usd"]').textContent = fmtInt(sum('farmer_usd'));
    const badge = $('[data-parcel-count]');
    badge.textContent = parcels.length;
    pempty.hidden = parcels.length > 0;
  }
  function wireDelete(btn, card, parcel) {
    let armed = null;
    btn.setAttribute('aria-label', `«${parcel.name}» алқабын өшіру`);
    btn.addEventListener('click', async () => {
      if (!armed) {
        btn.classList.add('is-confirm');
        btn.dataset.html = btn.innerHTML;
        btn.textContent = 'Өшіру?';
        armed = setTimeout(() => { btn.classList.remove('is-confirm'); btn.innerHTML = btn.dataset.html; armed = null; }, 3000);
        return;
      }
      clearTimeout(armed);
      btn.disabled = true;
      const fd = new FormData(); fd.append('csrf_token', csrf());
      try {
        const res = await fetch(`/dashboard/parcels/${parcel.id}/delete`, { method: 'POST', body: fd, headers: { Accept: 'application/json' } });
        if (!res.ok) throw new Error(res.status);
        const i = parcels.findIndex((p) => p.id === parcel.id);
        if (i >= 0) parcels.splice(i, 1);
        card.classList.add('is-removing');
        setTimeout(() => { card.remove(); updateParcelSums(); }, motionOn() ? 380 : 0);
        toast(`«${parcel.name}» алқабы өшірілді`);
      } catch {
        btn.disabled = false;
        toast('Өшіру мүмкін болмады. Бетті жаңартып көріңіз.', 'err');
      }
    });
  }
  function addCard(p) {
    const card = tpl.content.firstElementChild.cloneNode(true);
    card.dataset.id = p.id;
    $('[data-f="name"]', card).textContent = p.name;
    $('[data-f="meta"]', card).textContent = `${p.crop} · ${p.practice}`;
    $('[data-f="area_ha"]', card).textContent = fmtNum(p.area_ha);
    $('[data-f="tonnes"]', card).textContent = fmtNum(p.tonnes);
    $('[data-f="farmer_usd"]', card).textContent = '$' + fmtInt(p.farmer_usd);
    wireDelete($('.pcard__del', card), card, p);
    plist.append(card);
  }
  // Сервер жасаған карталарды JS-пен қайта құрамыз (сандар пішімі бірдей болсын)
  plist.innerHTML = '';
  parcels.forEach(addCard);
  updateParcelSums();

  const estimate = $('[data-estimate]');
  const areaInput = $('input[name="area_ha"]', form);
  areaInput.addEventListener('input', () => {
    const a = parseFloat(areaInput.value.replace(/\s/g, '').replace(',', '.'));
    if (!(a > 0)) { estimate.textContent = 'Бағалау: — т CO₂e/жыл · фермерге —'; return; }
    const t = a * DATA.netPerHa;
    estimate.textContent = `Бағалау: ${fmtNum(t)} т CO₂e/жыл · фермерге $${fmtInt(t * DATA.price * DATA.farmerShare)}`;
  });
  function showErrors(errors) {
    $$('[data-err]', form).forEach((el) => {
      const msg = errors[el.dataset.err] || '';
      el.textContent = msg;
      const field = el.closest('.f3');
      field.classList.remove('has-error');
      if (msg) { void field.offsetWidth; field.classList.add('has-error'); }
      $('input, select', field).setAttribute('aria-invalid', msg ? 'true' : 'false');
    });
    const firstBad = $('.f3.has-error input, .f3.has-error select', form);
    firstBad?.focus();
  }
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const submit = $('button[type="submit"]', form);
    const label = $('.btn__text', submit);
    submit.disabled = true;
    label.textContent = 'Сақталуда…';
    try {
      const res = await fetch(form.action, { method: 'POST', body: new FormData(form), headers: { Accept: 'application/json' } });
      if (res.status === 422) { showErrors((await res.json()).errors); return; }
      if (!res.ok) throw new Error(res.status);
      const { parcel } = await res.json();
      parcels.push(parcel);
      addCard(parcel);
      updateParcelSums();
      showErrors({});
      form.reset();
      estimate.textContent = 'Бағалау: — т CO₂e/жыл · фермерге —';
      closeDialog($('#parcel-modal'), () => go('parcels'));
      toast(`«${parcel.name}» алқабы қосылды · ${fmtNum(parcel.tonnes)} т CO₂e/жыл`);
    } catch {
      toast('Сақтау мүмкін болмады. Бетті жаңартып, қайта көріңіз.', 'err');
    } finally {
      submit.disabled = false;
      label.textContent = 'Сақтау';
    }
  });

  /* ── Интерфейс баптаулары ── */
  const motionToggle = $('[data-pref="motion"]');
  motionToggle.checked = store.get('motion', true) !== false;
  motionToggle.addEventListener('change', () => {
    html.classList.toggle('no-motion', !motionToggle.checked);
    store.set('motion', motionToggle.checked);
    toast(motionToggle.checked ? 'Анимациялар қосылды' : 'Анимациялар өшірілді');
  });
  compactToggle.addEventListener('change', () => setCollapsed(compactToggle.checked));

  /* ── Бастау ── */
  show(location.hash.slice(1) || 'overview');
  if (document.fonts?.ready) document.fonts.ready.then(() => { placeNavPill(); placeWeekPill(); $$('.seg').forEach((s) => placePill(s, $('.seg__pill', s), '.seg__btn.is-active')); });
})();
