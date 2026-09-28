  // ---- THE REAL-TIME WATERFALL --------------------------------------------
  //
  // WHAT THIS REPLACES, AND WHY IT KEPT BREAKING.
  //
  // The previous picture drew spectra COMPUTED AT THE FACTORY and then tried to
  // slide them into alignment with audio that reaches a listener about thirty
  // seconds later. That needs a lag constant, a client-side ring keyed to the
  // factory's clock, and a servo to keep a cursor tracking a moving edge. Each
  // was correct in isolation and the assembly drifted anyway: the cursor ran
  // past the newest column and clamped, the picture froze until the next
  // payload, and a backgrounded tab starved the frame loop so a timer had to be
  // added underneath it. Roberto, across three sessions: "the visualization is
  // offset and halts often", "the visualizer may be broken", "it just does not
  // work". Every fix tuned the alignment. None removed the need for it.
  //
  // There is nothing to align here. Each column is one FFT frame of the audio
  // the listener's own browser is decoding at that instant, so the picture is
  // synchronous with the ears by construction -- not to within a tolerance, but
  // exactly, because it is the same signal. No lag constant, no cursor, no
  // ring, no servo, no timer. About forty lines instead of three hundred.
  //
  // The cost is honest and stated on the page: this only exists while you are
  // listening, and only where the browser hands the stream to Web Audio. That
  // was already true of the level, centroid and peak readouts beside it.
  const RAMP = [
    [0.00, [176, 196, 208]],
    [0.18, [120, 168, 196]],
    [0.38, [ 96, 172, 150]],
    [0.58, [116, 168,  86]],
    [0.76, [206, 158,  62]],
    [0.90, [214, 104,  54]],
    [1.00, [200,  48,  48]]
  ];
  const alphaAt = u => Math.min(1, Math.max(0, (u - 0.05) * 1.3));
  function ink(u) {
    for (let i = 1; i < RAMP.length; i++) {
      if (u <= RAMP[i][0]) {
        const [a, ca] = RAMP[i - 1], [b, cb] = RAMP[i];
        const t = (u - a) / (b - a || 1);
        return [Math.round(ca[0] + (cb[0] - ca[0]) * t),
                Math.round(ca[1] + (cb[1] - ca[1]) * t),
                Math.round(ca[2] + (cb[2] - ca[2]) * t)];
      }
    }
    return [200, 48, 48];
  }

  // LOG FREQUENCY, because the factory's three layers are separated by octaves
  // and a linear axis spends four fifths of its height on material above 5 kHz
  // that is nearly always empty. Bottom of the canvas is low, as a spectrogram
  // is read.
  const F_LO = 40, F_HI = 16000;
  let wfCtx = null, wfW = 0, wfH = 0, wfRows = null, wfPaints = 0;

  function wfSize(cv) {
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const w = Math.max(1, Math.round(cv.clientWidth * dpr));
    const h = Math.max(1, Math.round((cv.clientHeight || 224) * dpr));
    if (w !== wfW || h !== wfH || !wfCtx) {
      // A canvas inside a hidden block measures 0, so this is re-checked every
      // frame and the picture starts the moment the block is revealed. The old
      // renderer sized once and could never recover from being measured hidden.
      cv.width = w; cv.height = h;
      wfW = w; wfH = h;
      wfCtx = cv.getContext("2d");
      // NEVER getContext("2d", {alpha:false}). getContext returns the same
      // context on every later call and ignores the options after the first, so
      // one opaque request permanently destroys the transparent ground -- which
      // is what turned the panel black on the exact click that started it.
      wfCtx.clearRect(0, 0, w, h);
      wfRows = null;
    }
    return wfCtx;
  }

  // Precomputed bin ranges per output row, so the per-frame work is a sum over
  // a slice rather than a log() per pixel per frame.
  function wfBuildRows(nBins, nyquist) {
    const rows = new Array(wfH);
    const lo = Math.log(F_LO), hi = Math.log(Math.min(F_HI, nyquist));
    for (let y = 0; y < wfH; y++) {
      // y = 0 is the TOP of the canvas and must be the HIGHEST frequency
      const u0 = 1 - (y + 1) / wfH, u1 = 1 - y / wfH;
      const f0 = Math.exp(lo + (hi - lo) * u0), f1 = Math.exp(lo + (hi - lo) * u1);
      let b0 = Math.floor(f0 / nyquist * nBins), b1 = Math.ceil(f1 / nyquist * nBins);
      b0 = Math.max(0, Math.min(nBins - 1, b0));
      b1 = Math.max(b0 + 1, Math.min(nBins, b1));
      rows[y] = [b0, b1];
    }
    wfRows = rows;
  }

  // One column per animation frame, scrolled in from the right.
  function wfColumn(f, nyquist) {
    const cv = document.getElementById("sd-spec");
    if (!cv || !cv.getContext) return;
    const ctx = wfSize(cv);
    if (!wfRows || wfRows.length !== wfH) wfBuildRows(f.length, nyquist);
    // scroll left by one column: drawing a canvas onto itself is defined and is
    // the cheapest scroll available, no offscreen buffer needed
    ctx.globalCompositeOperation = "copy";
    ctx.drawImage(cv, -1, 0);
    ctx.globalCompositeOperation = "source-over";
    ctx.clearRect(wfW - 1, 0, 1, wfH);
    for (let y = 0; y < wfH; y++) {
      const [b0, b1] = wfRows[y];
      let m = 0;
      for (let b = b0; b < b1; b++) if (f[b] > m) m = f[b];
      const u = m / 255;
      const a = alphaAt(u);
      if (a <= 0.004) continue;
      const c = ink(u);
      ctx.fillStyle = `rgba(${c[0]},${c[1]},${c[2]},${a.toFixed(3)})`;
      ctx.fillRect(wfW - 1, y, 1, 1);
    }
    wfPaints++;
  }

  // ---- THE SLOT RIBBON ----------------------------------------------------
  //
  // The figure that does NOT depend on the browser handing over the audio, and
  // the one a reviewer actually needs: three concurrent timescales, drawn from
  // the window log the panel already polls. Blocks are butted together, so a
  // machine held for sixteen windows reads as one long bar and a machine
  // redrawn every window reads as a picket fence. That distinction is the whole
  // claim of the three-slot architecture and until now it was invisible.
  //
  // No audio, no clock, no canvas: this cannot desync, halt, or fail in Safari.
  const LAYERS = ["macro", "mid", "micro"];
  function drawRibbon(slots) {
    const host = document.getElementById("sd-ribbon");
    if (!host) return;
    if (!slots || !slots.length) { host.innerHTML = ""; return; }
    const first = slots[0].w, last = slots[slots.length - 1].w;
    const span = Math.max(1, last - first + 1);
    let html = "";
    for (const lay of LAYERS) {
      // one run per (machine, start window) for this layer, in window order
      const mine = slots.filter(s => s.layer === lay);
      let cells = "";
      for (let i = 0; i < mine.length; i++) {
        const a = mine[i].w, b = (i + 1 < mine.length ? mine[i + 1].w : last + 1);
        const pct = (b - a) / span * 100;
        // the label is dropped rather than clipped when the run is too short to
        // hold it: a truncated machine name is worse than none
        const lab = pct > 7 ? mine[i].m : "";
        cells += `<i class="sd-rc" style="width:${pct.toFixed(3)}%"` +
                 ` title="${mine[i].m} · window ${a} · ${b - a} windows">${lab}</i>`;
      }
      html += `<div class="sd-rrow"><b>${lay}</b><div class="sd-rlane">${cells}</div></div>`;
    }
    host.innerHTML = html;
  }

  window.__sdRT = () => ({paints: wfPaints, w: wfW, h: wfH,
                          analyser: !!analyser, ctxState: actx && actx.state});
