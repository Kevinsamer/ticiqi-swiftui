(function () {
  'use strict';

  // ── Elements ──
  const $ = (id) => document.getElementById(id);
  const playZone = $('playZone');
  const playIcon = $('playIcon');
  const playLabel = $('playLabel');
  const seekTrack = $('seekTrack');
  const seekFill = $('seekFill');
  const seekThumb = $('seekThumb');
  const seekPct = $('seekPct');
  const statusDot = $('statusDot');
  const primaryView = $('primaryView');
  const secondaryView = $('secondaryView');
  const uploadView = $('uploadView');

  // ── Constants ──
  const PING_MS = 5000;
  const STALE_MS = 8000;
  const RECONNECT_MS = 2000;

  // ── State ──
  let ws = null;
  let reconnectTimer = null;
  let pingTimer = null;
  let staleTimer = null;
  let lastMsgTime = 0;
  let isPlaying = false;
  let isSeeking = false;
  let currentPage = 'library';
  let isSecondaryOpen = false;

  // ══════════════════════════════════════════
  //  WebSocket
  // ══════════════════════════════════════════

  function connect() {
    cleanup();
    const proto = location.protocol === 'https:' ? 'wss' : 'ws';
    ws = new WebSocket(`${proto}://${location.host}/ws`);

    ws.onopen = () => {
      lastMsgTime = Date.now();
      setConnected(true);
      clearTimeout(reconnectTimer);
      startTimers();
      send({ action: 'ping' });
    };

    ws.onmessage = (e) => {
      lastMsgTime = Date.now();
      try { onState(JSON.parse(e.data)); } catch (_) {}
    };

    ws.onclose = () => {
      stopTimers();
      setConnected(false);
      scheduleReconnect();
    };

    ws.onerror = () => ws.close();
  }

  function cleanup() {
    if (ws) { ws.onclose = null; ws.close(); ws = null; }
  }

  function scheduleReconnect() {
    clearTimeout(reconnectTimer);
    reconnectTimer = setTimeout(connect, RECONNECT_MS);
  }

  function startTimers() {
    stopTimers();
    pingTimer = setInterval(() => send({ action: 'ping' }), PING_MS);
    staleTimer = setInterval(() => {
      if (Date.now() - lastMsgTime > STALE_MS) {
        cleanup();
        setConnected(false);
        scheduleReconnect();
      }
    }, 1000);
  }

  function stopTimers() {
    clearInterval(pingTimer);
    clearInterval(staleTimer);
  }

  function disconnect() {
    stopTimers();
    clearTimeout(reconnectTimer);
    cleanup();
  }

  window.addEventListener('beforeunload', disconnect);
  window.addEventListener('pagehide', disconnect);

  function setConnected(ok) {
    statusDot.className = ok ? 'status-dot connected' : 'status-dot';
  }

  function send(msg) {
    if (ws && ws.readyState === WebSocket.OPEN) {
      try { ws.send(JSON.stringify(msg)); } catch (_) {}
    }
  }

  function haptic() {
    if (navigator.vibrate) navigator.vibrate(10);
  }

  // ══════════════════════════════════════════
  //  State update
  // ══════════════════════════════════════════

  function showView(view) {
    primaryView.style.display = view === 'primary' ? 'flex' : 'none';
    uploadView.style.display = view === 'upload' ? 'flex' : 'none';
    // Secondary uses CSS class for animation, not display toggle
    secondaryView.classList.toggle('visible', view === 'secondary');
    if (view === 'secondary') isSecondaryOpen = true;
  }

  function onState(s) {
    // Page context — don't dismiss secondary panel on state updates
    if (s.currentPage) {
      currentPage = s.currentPage;
      if (!isSecondaryOpen) {
        showView(currentPage === 'library' ? 'upload' : 'primary');
      }
    }

    // Play state
    isPlaying = !!s.isPlaying;
    playIcon.innerHTML = isPlaying ? '&#9646;&#9646;' : '&#9654;';
    playLabel.textContent = isPlaying ? '暂停' : '播放';

    // Progress (don't update while user is seeking)
    if (!isSeeking) {
      const pct = Math.round((s.scrollProgress || 0) * 100);
      updateSeekUI(pct);
    }

    // Speed
    const speed = Math.round(s.scrollSpeed || 30);
    $('valSpeed').textContent = speed;
    $('speedSlider').value = speed;
    document.querySelectorAll('.preset-btn').forEach((b) => {
      b.classList.toggle('active', parseInt(b.dataset.speed) === speed);
    });

    // Font
    const font = Math.round(s.fontSize || 48);
    $('valFont').textContent = font;
    $('fontSlider').value = font;

    // Toggles
    $('btnMirror').classList.toggle('active', !!s.mirrorEnabled);
    $('btnFocusLine').classList.toggle('active', !!s.focusLineEnabled);
    const up = s.scrollDirection !== 'down';
    $('dirIcon').innerHTML = up ? '&#8593;' : '&#8595;';
    $('dirText').textContent = up ? '向上' : '向下';
  }

  function updateSeekUI(pct) {
    seekPct.textContent = pct + '%';
    seekFill.style.width = pct + '%';
    seekThumb.style.left = pct + '%';
  }

  // ══════════════════════════════════════════
  //  Play/Pause — entire screen tap
  // ══════════════════════════════════════════

  playZone.addEventListener('click', (e) => {
    // Ignore if user was seeking
    if (isSeeking) return;
    haptic();
    send({ action: isPlaying ? 'pause' : 'play' });
  });

  // ══════════════════════════════════════════
  //  Seek bar — drag to seek
  // ══════════════════════════════════════════

  function seekFromEvent(e) {
    const rect = seekTrack.getBoundingClientRect();
    const x = (e.touches ? e.touches[0].clientX : e.clientX) - rect.left;
    const pct = Math.max(0, Math.min(100, (x / rect.width) * 100));
    updateSeekUI(Math.round(pct));
    send({ action: 'seek', value: pct / 100 });
  }

  function onSeekStart(e) {
    isSeeking = true;
    haptic();
    seekFromEvent(e);
  }

  function onSeekMove(e) {
    if (!isSeeking) return;
    e.preventDefault();
    seekFromEvent(e);
  }

  function onSeekEnd() {
    if (!isSeeking) return;
    isSeeking = false;
  }

  // Mouse events
  seekTrack.addEventListener('mousedown', onSeekStart);
  window.addEventListener('mousemove', onSeekMove);
  window.addEventListener('mouseup', onSeekEnd);

  // Touch events — on the entire seek strip for larger hit area
  const seekStrip = $('seekStrip');
  seekStrip.addEventListener('touchstart', (e) => {
    isSeeking = true;
    haptic();
    const rect = seekTrack.getBoundingClientRect();
    const x = e.touches[0].clientX - rect.left;
    const pct = Math.max(0, Math.min(100, (x / rect.width) * 100));
    updateSeekUI(Math.round(pct));
    send({ action: 'seek', value: pct / 100 });
  }, { passive: true });

  seekStrip.addEventListener('touchmove', (e) => {
    if (!isSeeking) return;
    e.preventDefault();
    const rect = seekTrack.getBoundingClientRect();
    const x = e.touches[0].clientX - rect.left;
    const pct = Math.max(0, Math.min(100, (x / rect.width) * 100));
    updateSeekUI(Math.round(pct));
    send({ action: 'seek', value: pct / 100 });
  }, { passive: false });

  seekStrip.addEventListener('touchend', onSeekEnd);

  // ══════════════════════════════════════════
  //  Secondary panel
  // ══════════════════════════════════════════

  function showSecondary() {
    isSecondaryOpen = true;
    secondaryView.classList.add('visible');
  }

  function hideSecondary() {
    isSecondaryOpen = false;
    secondaryView.style.pointerEvents = 'none';
    secondaryView.querySelector('.sec-sheet').style.transform = 'translateY(100%)';
    secondaryView.querySelector('.sec-backdrop').style.opacity = '0';
    // Remove class after slide-down animation completes
    clearTimeout(hideSecondary._timer);
    hideSecondary._timer = setTimeout(() => {
      secondaryView.classList.remove('visible');
      secondaryView.style.pointerEvents = '';
      secondaryView.querySelector('.sec-sheet').style.transform = '';
      secondaryView.querySelector('.sec-backdrop').style.opacity = '';
      showView(currentPage === 'library' ? 'upload' : 'primary');
    }, 350);
  }

  $('btnMore').addEventListener('click', () => { haptic(); showSecondary(); });
  $('btnBack').addEventListener('click', () => { haptic(); hideSecondary(); });
  $('secBackdrop').addEventListener('click', () => { hideSecondary(); });

  // Speed slider
  $('speedSlider').addEventListener('input', () => {
    send({ action: 'speed', value: parseInt($('speedSlider').value) });
  });

  // Speed presets
  document.querySelectorAll('.preset-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      haptic();
      send({ action: 'speed', value: parseInt(btn.dataset.speed) });
    });
  });

  // Font slider
  $('fontSlider').addEventListener('input', () => {
    send({ action: 'fontSize', value: parseInt($('fontSlider').value) });
  });

  // Toggles
  $('btnMirror').addEventListener('click', () => { haptic(); send({ action: 'mirror' }); });
  $('btnFocusLine').addEventListener('click', () => { haptic(); send({ action: 'focusLine' }); });
  $('btnDirection').addEventListener('click', () => { haptic(); send({ action: 'scrollDirection' }); });

  // ══════════════════════════════════════════
  //  File upload
  // ══════════════════════════════════════════

  async function uploadText(text, name) {
    $('uploadStatus').textContent = '上传中...';
    try {
      const r = await fetch('/upload', {
        method: 'POST',
        body: text,
        headers: { 'Content-Type': 'text/plain; charset=utf-8' }
      });
      $('uploadStatus').textContent = r.ok ? '✔ ' + name : '✘ 上传失败';
    } catch (_) {
      $('uploadStatus').textContent = '✘ 上传失败';
    }
  }

  $('fileUpload').addEventListener('change', () => {
    const file = $('fileUpload').files[0];
    if (!file) return;
    const ext = file.name.split('.').pop().toLowerCase();

    if (ext === 'txt') {
      const reader = new FileReader();
      reader.onload = (e) => {
        const t = e.target.result;
        t && t.trim() ? uploadText(t, file.name) : ($('uploadStatus').textContent = '✘ 文件为空');
      };
      reader.onerror = () => ($('uploadStatus').textContent = '✘ 读取失败');
      reader.readAsText(file, 'UTF-8');
    } else if (ext === 'docx') {
      $('uploadStatus').textContent = '解析中...';
      readDocx(file).then((t) => {
        t && t.trim() ? uploadText(t, file.name) : ($('uploadStatus').textContent = '✘ 内容为空');
      }).catch(() => ($('uploadStatus').textContent = '✘ 解析失败'));
    } else {
      $('uploadStatus').textContent = '仅支持 .txt / .docx';
    }
  });

  async function readDocx(file) {
    const buf = await file.arrayBuffer();
    const v = new DataView(buf);
    const d = new TextDecoder('utf-8');
    let eocd = -1;
    for (let i = buf.byteLength - 22; i >= 0 && i > buf.byteLength - 66000; i--) {
      if (v.getUint32(i, true) === 0x06054b50) { eocd = i; break; }
    }
    if (eocd < 0) throw new Error('ZIP not found');
    const cdOff = v.getUint32(eocd + 16, true);
    const cdSize = v.getUint32(eocd + 12, true);
    let found = null;
    let pos = cdOff;
    while (pos < cdOff + cdSize - 46) {
      if (v.getUint32(pos, true) !== 0x02014b50) { pos++; continue; }
      const nl = v.getUint16(pos + 28, true);
      const el = v.getUint16(pos + 30, true);
      const cl = v.getUint16(pos + 32, true);
      const name = d.decode(new Uint8Array(buf, pos + 46, nl));
      if (name === 'word/document.xml') {
        found = { method: v.getUint16(pos + 10, true), size: v.getUint32(pos + 20, true), off: v.getUint32(pos + 42, true) };
        break;
      }
      pos += 46 + nl + el + cl;
    }
    if (!found) throw new Error('document.xml not found');
    const lnl = v.getUint16(found.off + 26, true);
    const lel = v.getUint16(found.off + 28, true);
    const ds = found.off + 30 + lnl + lel;
    let bytes;
    if (found.method === 0) bytes = new Uint8Array(buf, ds, found.size);
    else if (found.method === 8) {
      const blob = new Blob([new Uint8Array(buf, ds, found.size)]);
      bytes = new Uint8Array(await new Response(blob.stream().pipeThrough(new DecompressionStream('deflate-raw'))).arrayBuffer());
    } else throw new Error('Unsupported compression');
    return d.decode(bytes).replace(/<w:p[^>]*>/gi, '\n').replace(/<[^>]+>/g, '').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/\n{3,}/g, '\n\n').trim();
  }

  // ══════════════════════════════════════════
  //  Pull-to-refresh (custom gesture)
  // ══════════════════════════════════════════

  const PULL_THRESHOLD = 80;
  let pullStartY = 0;
  let pulling = false;
  let refreshing = false;

  const indicator = document.createElement('div');
  indicator.id = 'pullIndicator';
  Object.assign(indicator.style, {
    position: 'fixed', top: '0', left: '50%', transform: 'translate(-50%, -60px)',
    zIndex: '999', padding: '8px 20px', borderRadius: '20px',
    background: 'rgba(255,255,255,0.15)', backdropFilter: 'blur(10px)',
    WebkitBackdropFilter: 'blur(10px)', color: '#fff', fontSize: '14px',
    transition: 'transform 0.2s ease, opacity 0.2s ease', opacity: '0',
    pointerEvents: 'none',
  });
  indicator.textContent = '下拉刷新';
  document.body.appendChild(indicator);

  document.addEventListener('touchstart', (e) => {
    if (refreshing || e.touches.length !== 1) return;
    const activeEl = document.activeElement;
    if (activeEl && (activeEl.tagName === 'INPUT' || activeEl.tagName === 'TEXTAREA')) return;
    pullStartY = e.touches[0].clientY;
    pulling = true;
  }, { passive: true });

  document.addEventListener('touchmove', (e) => {
    if (!pulling || refreshing) return;
    const dy = e.touches[0].clientY - pullStartY;
    if (dy > 10) {
      indicator.style.opacity = Math.min(dy / PULL_THRESHOLD, 1);
      indicator.style.transform = `translate(-50%, ${Math.min(dy * 0.4, 50) - 60}px)`;
      indicator.textContent = dy >= PULL_THRESHOLD ? '释放刷新' : '下拉刷新';
    }
  }, { passive: true });

  document.addEventListener('touchend', (e) => {
    if (!pulling || refreshing) { pulling = false; return; }
    const dy = (e.changedTouches[0]?.clientY || 0) - pullStartY;
    pulling = false;
    if (dy >= PULL_THRESHOLD) {
      refreshing = true;
      indicator.textContent = '刷新中...';
      indicator.style.transform = 'translate(-50%, 10px)';
      indicator.style.opacity = '1';
      haptic();
      setTimeout(() => location.reload(), 300);
    } else {
      indicator.style.transform = 'translate(-50%, -60px)';
      indicator.style.opacity = '0';
    }
  }, { passive: true });

  // ── Init ──
  connect();
})();
