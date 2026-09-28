(function () {
  const RELAY  = "https://stream.robertoalonsotrillo.com";
  const STATUS = RELAY + "/status-json.xsl";

  // TWO FACTORIES ON ONE RELAY.
  //
  // One Icecast server carries as many mounts as sources authenticate for, so
  // both factories publish to the same host and nothing extra was provisioned.
  // Each has its OWN state file: two factories writing one state.json would
  // overwrite each other every ten seconds and the panel would show whichever
  // wrote last, flickering between two systems while claiming to describe one.
  //
  // Factory 2 keeps /superdark.mp3 and /state.json, the paths that already
  // exist, so adding Factory 1 required no change to a running factory and
  // breaks no link anyone has saved.
  //
  // NOTE FOR LATER: the canonical mount is held by the DEVELOPMENT machine,
  // which is the one that restarts most -- four times in twenty-five minutes on
  // 16 Sept. If the continuous factory should own the address people bookmark,
  // swap the two `mount` values below and restart both. One line each side.
  const FACTORIES = {
    "1": { name: "Factory 1", mount: "/replica.mp3",
           state: "/state-replica.json",
           note: "runs continuously on its own machine" },
    "2": { name: "Factory 2", mount: "/superdark.mp3",
           state: "/state.json",
           note: "the development factory, restarted often" }
  };

  // let, not const: these are repointed when the listener switches factory.
  //
  // DEFAULT IS THE FACTORY THAT HAS DATA, AND THAT IS TEMPORARY.
  // Factory 1 is the continuous instance and is the one a visitor should
  // ordinarily land on. But as of 17 Sept 2026 the relay serves a PLACEHOLDER
  // at /state-replica.json -- the literal string
  // "superdark - the stream is at /superdark.mp3", not JSON -- because the
  // replica publishes its audio but not yet its panel data. Defaulting to
  // Factory 1 would therefore hide the evaluation panel from every visitor who
  // arrives without a query string, which is most of them, and the panel is a
  // large part of what this page is for.
  //
  // So the default is Factory 2 until the replica publishes real state.
  // ?factory=1 still selects the replica, and the buttons still switch freely.
  // FLIP THIS BACK the moment /state-replica.json returns JSON; leaving it is
  // the same failure this file already carries a comment about -- a temporary
  // workaround that outlives the condition it worked around.
  const q = new URLSearchParams(location.search).get("factory");
  let FACTORY = (q === "1" || q === "2") ? q : "2";
  let STREAM = RELAY + FACTORIES[FACTORY].mount;
  let STATE  = RELAY + FACTORIES[FACTORY].state;

  // A MISSING ELEMENT MUST NOT KILL THE PAGE.
  // The markup lives in the WordPress block; the code lives on the relay. They
  // are deployed separately, so the code can arrive ahead of the markup it
  // expects -- and on 2 Sept it did: a new readout div was referenced by
  // panel.js before the block carrying it had been republished, the null
  // dereference threw inside the render loop, and the spectrogram, the meters
  // and the notice all vanished together with no message to say why.
  //
  // Returning a harmless stand-in keeps a missing element to a missing element.
  // The alternative is that every future markup addition is a live outage until
  // two deployments happen in the right order.
  const NOWHERE = {textContent: "", innerHTML: "", style: {}, hidden: true,
                   addEventListener() {}, getContext: () => null,
                   querySelectorAll: () => [], appendChild() {}};
  const $ = id => document.getElementById(id) || NOWHERE;
  const btn = $("sd-play"), stat = $("sd-status");
  let audio = null, playing = false;

  function setState(t, live) {
    stat.innerHTML = live ? `<span class="sd-live"></span><b>${t}</b>` : t;
  }
  btn.disabled = false; setState("ready", false);
  // ---- SWITCHING FACTORY ---------------------------------------------------
  //
  // The audio and the panel move TOGETHER. A panel describing one factory over
  // the audio of another is worse than no panel: every number on it would be
  // wrong in a way that looks authoritative. So this repoints both, clears the
  // readouts that belong to the factory being left, and only then polls.
  //
  // If audio was playing it resumes on the new mount, because a listener who
  // clicks "Factory 2" while listening means "play that one", not "stop".
  function selectFactory(id, opts) {
    if (!FACTORIES[id] || id === FACTORY) return;
    const wasPlaying = playing;
    if (wasPlaying) { try { stop(); } catch (e) {} }

    FACTORY = id;
    STREAM  = RELAY + FACTORIES[id].mount;
    STATE   = RELAY + FACTORIES[id].state;

    document.querySelectorAll(".sd-fbtn").forEach(b => {
      b.classList.toggle("is-on", b.dataset.factory === id);
      b.setAttribute("aria-pressed", b.dataset.factory === id ? "true" : "false");
    });

    // Blank rather than leave the previous factory's figures standing while the
    // new state.json is in flight. A stale number with a new label is a lie.
    //
    // HIDE THE WHOLE PANEL, DO NOT BLANK A LIST OF IDS.
    // The first version named six elements. draw() writes into about
    // twenty-eight -- sd-metrics, sd-verdict, sd-ed, sd-vocab, sd-roster,
    // sd-trace, sd-spec, sd-gaps and the rest -- so switching factories blanked
    // the six counters and left the CHARTER VERDICT AND EVERY METRIC ROW
    // standing, which is the most authoritative-looking content on the page and
    // would have been attributed to the wrong factory. The comment above stated
    // the right rule and the code implemented a quarter of it.
    //
    // A list of ids has to be kept in step with draw() for ever and silently
    // rots the moment a readout is added. Hiding the container cannot miss an
    // element. draw() sets hidden = false again as soon as it has real data for
    // the factory now selected, so the panel returns by itself or not at all.
    //
    // This also covers the case that prompted it: /state-replica.json currently
    // serves a placeholder rather than JSON, so pollState throws, draw() is
    // never called, and the panel stays hidden instead of misreporting.
    { const p = $("sd-panel"); if (p !== NOWHERE) p.hidden = true; }
    ["sd-win", "sd-mach", "sd-voices", "sd-uptime", "sd-facup", "sd-listeners"]
      .forEach(k => { const el = $(k); if (el !== NOWHERE) el.textContent = "—"; });
    setState("ready", false);

    // Keep the address bar honest so a reload, or a shared link, lands on the
    // factory actually being heard.
    if (!(opts && opts.silent) && window.history && history.replaceState) {
      const u = new URL(location.href);
      u.searchParams.set("factory", id);
      history.replaceState(null, "", u);
    }

    // pollState and pollIce, BY THEIR REAL NAMES. This read `poll()` guarded by
    // a typeof check, which meant a switch silently refreshed nothing and the
    // panel kept the old factory's figures until the next timer tick. The guard
    // made it look deliberate. Same shape as every other mechanism in this
    // project found built and wired to nothing.
    if (typeof pollState === "function") { try { pollState(); } catch (e) {} }
    if (typeof pollIce   === "function") { try { pollIce();   } catch (e) {} }
    if (wasPlaying) { try { btn.click(); } catch (e) {} }
  }

  document.querySelectorAll(".sd-fbtn").forEach(b => {
    b.setAttribute("aria-pressed", b.dataset.factory === FACTORY ? "true" : "false");
    b.classList.toggle("is-on", b.dataset.factory === FACTORY);
    b.addEventListener("click", () => selectFactory(b.dataset.factory));
  });


  btn.addEventListener("click", () => {
    if (playing) { stop(); return; }
    // WHY SAFARI NEVER GOT AN ANALYSER, AND IT WAS NEVER CORS.
    //
    // startAnalyser was `async` and did `await actx.resume()`. In Safari the
    // user-gesture privilege that allows an AudioContext to enter the running
    // state does not survive an await: by the time resume() settles the click
    // is over, the context stays "suspended", and the guard inside -- which is
    // correct, because capturing an element on a suspended context mutes the
    // listener -- returned before ever creating the analyser. So on Safari
    // loop() never ran, and the level, centroid and peak readouts fell back to
    // the factory's published medians for the whole session. Every explanation
    // written into this file blamed cross-origin routing. It was the await.
    //
    // The whole graph is therefore built SYNCHRONOUSLY inside the handler,
    // before anything that yields. Nothing here awaits, nothing here is async,
    // and resume() is fired without being waited on.
    const AC = window.AudioContext || window.webkitAudioContext;
    if (AC) {
      try {
        actx = actx || new AC();
        if (actx.state !== "running" && actx.resume) actx.resume();
      } catch (e) { actx = null; }
    }
    // Rebuilt on every play. A stream is not seekable, so a paused element holds
    // a stale buffer; reconstructing guarantees the listener joins at the
    // factory's present instead of wherever they left it.
    audio = new Audio();
    // MUST be set before src, and the mount MUST send Access-Control-Allow-Origin
    // or the element refuses to play at all. The header was added to Caddy's
    // /superdark.mp3 route for exactly this; without it the analyser would give
    // silence and, worse, take the audio down with it.
    audio.crossOrigin = "anonymous";
    audio.src = STREAM; audio.preload = "none";
    startAnalyser(audio);
    audio.addEventListener("playing", () => { playing = true; btn.textContent = "stop"; setState("live", true); });
    audio.addEventListener("waiting", () => setState("buffering…", false));
    // NOT "stopped". A factory that is unreachable has died, and it does not
    // resume: the next one that appears here is a different factory.
    audio.addEventListener("error", () => { setState("this factory is dead", false); reset(); });
    audio.addEventListener("ended", () => { setState("this factory is dead", false); reset(); });
    setState("connecting…", false);
    audio.play().catch(() => { setState("could not start", false); reset(); });
  });
  function stop() { if (audio) { audio.pause(); audio.src = ""; } reset(); setState("stopped", false); }
  function reset() { playing = false; btn.textContent = "listen"; audio = null; stopAnalyser(); }

  // ---- the real-time layer -------------------------------------------------
  // Everything else here comes from the window log, and the window is 11.7 s, so
  // no derived figure can honestly move faster. This reads the decoded audio in
  // the listener's own browser at frame rate. It is not a summary; it is the
  // sound itself, and it costs the server nothing.
  //
  // The centroid computed here is the same quantity m8 tests. Seeing it live
  // beside m8's median over the run is the point: one is what the factory is
  // doing this instant, the other is what it has done all run.
  let actx = null, analyser = null, srcNode = null, raf = 0, sctx = null;
  // The factory's own recent output level, from the published trace. Starts at 0
  // so the watchdog stays inert until the page has actually heard from the
  // factory -- it must never act on an assumption.
  let flatSince = 0, silentNote = false, factoryPeakRecent = 0;
  let frames = 0, peakSeen = 0;
  // Has the visitor's own analyser ever heard anything, and what the factory
  // last published, so the readouts have somewhere to fall back to.
  let rtAlive = false, rtStart = 0, mirrorTop = false;
  let pubLevel = null, pubCent = null, pubPeak = null;

  // THE WATCHDOG, and why it is not optional.
  // On some browsers a media element decodes and advances -- readyState 4,
  // currentTime climbing, no error -- while delivering DIGITAL SILENCE into the
  // Web Audio graph. Observed directly while building this: an oscillator
  // through the same context read correctly, so the graph was fine and only the
  // media path was dead. Because createMediaElementSource permanently reroutes
  // the element, that failure MUTES THE LISTENER while the page reports "live".
  // There is no event for it, so it has to be watched for.
  //
  // DISTINGUISHING A MUTED PIPE FROM A SILENT FACTORY, which is the whole
  // difficulty. This factory is genuinely silent in about 21% of its windows, so
  // "the analyser reads nothing" is not by itself evidence of a fault. An
  // earlier version tested for an EXACT flatline (min == max == 128) and never
  // fired, because a single bit of dither at 127 defeated it.
  //
  // The client cannot settle this alone, so it asks the factory. The panel
  // already polls the factory's own per-window peaks; if those show sound while
  // the analyser hears nothing for six seconds, the browser is the problem. If
  // the factory reports silence too, the analyser is simply telling the truth
  // and nothing should happen.
  // THE WATCHDOG NO LONGER TEARS ANYTHING DOWN, and the reason is a measurement.
  //
  // Its first version rebuilt playback without analysis whenever the analyser
  // read silence for six seconds while the factory's published peaks showed
  // sound. In Safari that fired constantly: the spectrogram and the sound would
  // both stop, the sound would return, and the meters would stay dead for the
  // rest of the session.
  //
  // The cause is that the factory is SUPPOSED to go silent. 47% of windows carry
  // a section amplitude below 0.0001, and 45% of those are silent by m1's
  // threshold; silent runs reach five windows, close to a minute. There is no
  // duration that separates the factory's intended silence from a muted graph,
  // so a watchdog keyed on duration will always misread the work as a fault.
  //
  // The failure it was defending against is prevented at the source instead:
  // the element is never captured unless the AudioContext is already running,
  // and the mount sends CORS headers, so the two ways a graph can silently mute
  // a listener are both closed before capture. What remains is a passive
  // notice — never an intervention on the audio.
  // THE FALLBACK CANNOT LIVE INSIDE loop(), WHICH IS WHERE I PUT IT.
  //
  // loop() only runs when an analyser exists. Safari refuses to route a
  // cross-origin media element into an AudioContext, and the guard above returns
  // BEFORE creating one whenever the context will not enter the running state --
  // so on the browser the fallback was written for, loop() never executed and
  // the three readouts stayed at "—" for ever. The fallback tested clean because
  // I only ever exercised it where the analyser worked.
  //
  // Called from every poll instead, so it fills the readouts whether the
  // analyser was never created, was created and hears nothing, or does not
  // exist because the visitor has not pressed listen at all.
  function showPublished() {
    const alive = rtAlive && analyser;
    if (alive) return;                       // live audio wins when it works
    const waited = rtStart && (performance.now() - rtStart > 6000);
    if (analyser && !waited) return;          // give a new analyser its 6 s
    $("sd-rtlevel").textContent = pubLevel == null ? "—" : pubLevel.toFixed(1);
    $("sd-rtpeak").textContent  = pubPeak  == null ? "—" : pubPeak.toFixed(3);
    $("sd-rtcent").textContent  = pubCent  == null ? "—" : Math.round(pubCent);
    $("sd-rtsrc").textContent = analyser
      ? "from the factory's own output, median peak per window — your browser " +
        "will not pass this stream to Web Audio, so it cannot be read from what you hear"
      : "from the factory's own output, median peak per window";
    // and the numbers are visible without pressing listen, which is what a
    // visitor who only wants to look at the panel should get
    const on = document.getElementById("sd-rton");
    if (on && on.hidden && pubPeak != null) on.hidden = false;
  }

  function watchdog(rms) {
    const quiet = rms < 1e-4;
    if (!quiet || factoryPeakRecent < 0.02) {
      flatSince = 0;
      if (silentNote) { silentNote = false; $("sd-rtnote").textContent = ""; }
      return;
    }
    if (!flatSince) { flatSince = performance.now(); return; }
    if (performance.now() - flatSince < 30000 || silentNote) return;
    silentNote = true;
    $("sd-rtnote").textContent =
      "the meters read nothing while the factory reports sound — if this persists, your browser is not passing the stream to the analyser";
  }
  // NOT async, and that is the fix. See the click handler: an await here costs
  // Safari the user-gesture privilege and with it the entire real-time layer.
  // The context is created and resumed by the caller, synchronously, and this
  // function only ever inspects the state it finds.
  function startAnalyser(el) {
    try {
      if (!actx) return;
      // THE CONTEXT MUST BE RUNNING BEFORE THE ELEMENT IS CAPTURED.
      // createMediaElementSource permanently reroutes the element's output into
      // the graph, so on a suspended context the listener gets SILENCE while the
      // page still reports "live". Caught in testing, where an untrusted click
      // left the context suspended and the meters read -inf against a stream
      // that was supposedly playing. Analysis is optional; audio is not, so if
      // the context will not run we never touch the element.
      if (actx.state !== "running") {
        $("sd-rtoff").hidden = false; $("sd-rton").hidden = true;
        $("sd-rtoff").textContent =
          "your browser is holding audio analysis back — the stream plays, the meters do not";
        return;
      }
      analyser = actx.createAnalyser();
      analyser.fftSize = 2048;
      analyser.smoothingTimeConstant = 0.72;
      // A fresh element each play means a fresh source node; the context is
      // reused because browsers cap how many can exist.
      srcNode = actx.createMediaElementSource(el);
      srcNode.connect(analyser);
      analyser.connect(actx.destination);   // omit this and the page goes silent
      // THE CANVAS IS NOT TOUCHED HERE, AND THAT IS A FIX.
      // This used to do getContext("2d", {alpha:false}) and fill the canvas
      // opaque grey. getContext returns the SAME context object on every later
      // call and ignores the options after the first one, so once a visitor
      // pressed listen the waterfall's ground was permanently opaque -- and
      // paintSpectrogram's clearRect, which exists so the page shows through,
      // could never produce transparency again. The reported "black background"
      // appeared on exactly the click that was supposed to start the meters.
      // The live analyser stopped drawing the spectrogram some time ago, so
      // sctx had no remaining purpose except to break the other renderer.
      $("sd-rtoff").hidden = true; $("sd-rton").hidden = false;
      flatSince = 0;
      loop();
    } catch (e) {
      // Analysis is a bonus. If the context or CORS fails the stream must still
      // play, so this never rethrows.
      $("sd-rtoff").hidden = false; $("sd-rton").hidden = true;
    }
  }
  function stopAnalyser() {
    cancelAnimationFrame(raf); raf = 0; analyser = null;
    try { srcNode && srcNode.disconnect(); } catch (e) {}
    srcNode = null;
    $("sd-rtoff").hidden = false; $("sd-rton").hidden = true;
  }
  function loop() {
    if (!analyser) return;
    // A backgrounded tab can suspend the context after the fact, which would
    // mute a graph the element is already routed through. Nudge it back.
    if (actx && actx.state === "suspended") { actx.resume().catch(() => {}); }
    const n = analyser.frequencyBinCount;
    const f = new Uint8Array(n), t = new Uint8Array(analyser.fftSize);
    analyser.getByteFrequencyData(f);
    analyser.getByteTimeDomainData(t);

    let sum = 0, peak = 0;
    for (let i = 0; i < t.length; i++) {
      const v = (t[i] - 128) / 128;
      sum += v * v; if (Math.abs(v) > peak) peak = Math.abs(v);
    }
    const rms = Math.sqrt(sum / t.length);
    watchdog(rms);

    let num = 0, den = 0;
    const hzPerBin = actx.sampleRate / analyser.fftSize;
    for (let i = 0; i < n; i++) { num += f[i] * i * hzPerBin; den += f[i]; }

    // FALL BACK TO THE FACTORY WHEN THE BROWSER WILL NOT HAND OVER THE AUDIO.
    // Safari refuses to route a cross-origin media element into an AudioContext,
    // so createMediaElementSource yields a permanently silent graph: level,
    // centroid and peak read nothing while the sound plays perfectly. Chrome
    // allows it, which is why the same three numbers track the sound there and
    // are dead here. Three empty readouts on one browser and live ones on
    // another look like a broken page.
    //
    // The factory already publishes the same quantities, measured on its own
    // output, and the page already polls them. So when the analyser has heard
    // nothing for six seconds while audio is playing, these switch to the
    // published values.
    //
    // They are NOT the same measurement and the caption says so. The live
    // reading is RMS of the visitor's own decoded audio at frame rate; the
    // published one is the factory's median master PEAK per 11.7 s window,
    // before the encoder. Presenting a peak as though it were the RMS the
    // visitor is hearing would be exactly the kind of quiet substitution this
    // project keeps finding in its own metrics.
    if (rms > 1e-5) rtAlive = true;
    if (!rtStart) rtStart = performance.now();
    if (rtAlive) {
      $("sd-rtlevel").textContent = rms > 1e-5 ? (20 * Math.log10(rms)).toFixed(1) : "−∞";
      $("sd-rtpeak").textContent = peak.toFixed(3);
      $("sd-rtcent").textContent = den > 0 ? Math.round(num / den) : "—";
      $("sd-rtsrc").textContent = "read from the audio in your browser, at frame rate";
    }
    // when the analyser is running but silent, showPublished() below fills in

    // THE ANALYSER DRAWS THE WATERFALL AGAIN, and this time it is the only
    // renderer touching that canvas.
    //
    // It was switched off (an `if (false)`, left in place) because it painted
    // over a second picture that came from the factory. That second picture is
    // gone: it needed a thirty-second lag constant and a cursor servo to sit
    // where the ears are, and drifted anyway. One canvas, one owner, and the
    // owner is the audio the visitor is actually decoding -- so "offset" is not
    // a defect that has been reduced, it is a quantity that no longer exists.
    try { wfColumn(f, actx.sampleRate / 2); } catch (e) {}
    raf = requestAnimationFrame(loop);
  }

  // One duration formatter for both clocks, so the two figures beside each
  // other cannot be formatted differently and read as different quantities.
  const dur = secs => {
    if (secs == null || !isFinite(secs) || secs < 0) return "—";
    const h = Math.floor(secs / 3600), m = Math.floor((secs % 3600) / 60);
    return h >= 24 ? `${Math.floor(h / 24)}d ${h % 24}h`
         : h ? `${h}h ${m}m` : `${m}m`;
  };

  const nfmt = n => n == null ? "—"
    : n >= 1e6 ? (n/1e6).toFixed(1)+"M" : n >= 1e3 ? (n/1e3).toFixed(1)+"K" : String(n);
  // Counts print as counts. m4 is a count of distinct behaviours and reading
  // "36.000" invites the eye to look for a precision that is not there.
  const round = (v, p) => v == null ? "—"
    : Number.isInteger(v) ? String(v)
    : Math.abs(v) >= 100 ? v.toFixed(0) : v.toFixed(p);

  function metricRow(m) {
    // WHERE the value sits inside its acceptable region, as a position on a bar.
    // One-sided bounds (m4 lost its ceiling when the charter was re-priced) get
    // a half-open scale anchored on the bound that exists, so the mark still
    // means something instead of pinning to an edge.
    let pos = null, open = false;
    if (m.value != null && m.lo != null && m.hi != null && m.hi > m.lo) {
      pos = (m.value - m.lo) / (m.hi - m.lo);
    } else if (m.value != null && m.lo != null) {
      // OPEN ABOVE. m4 lost its ceiling when the charter was re-priced, because
      // the old one was just the calibration run's own observed value and a cap
      // on variety contradicts the norm it serves. So the mark must NOT pin to
      // the right edge, which would read as a metric pressed against a limit
      // that does not exist. Capped at 0.8 with the track fading out past it.
      pos = Math.min(0.8, m.value / (m.lo * 4 || 1)); open = true;
    } else if (m.value != null && m.hi != null) {
      pos = m.value / (m.hi || 1);
    }
    const fail = m.verdict === "FAIL";
    // NOT MEASURED greys out like an undecided metric, because that is what it
    // is: m3b_delivered_peak comes from a network capture rather than the window
    // log, so it can be absent on a run every other metric scored. It keeps its
    // own word in the verdict column -- "—" would read as a thin run, and this
    // one is never-tolerated, so the reader has to see that nothing measured it.
    const notm = m.verdict === "NOT MEASURED";
    const und  = m.verdict === "UNDECIDED" || notm;
    const clamp = pos == null ? null : Math.max(0, Math.min(1, pos));
    // KEYS ARE NOT ALL m<digit>_ ANY MORE. Charter edition 7 gave the two
    // unbounded DESCRIPTIONS a d-prefix (d1_silence, d2_turnover) and added
    // m3b_delivered_peak, whose ordinal carries a letter. The old /^m\d+/ match
    // returned null on both shapes and threw on [0], taking the whole panel down
    // with it, so the prefix is parsed generically and never indexed blind.
    const pfx = (m.key.match(/^[a-z]+\d+[a-z]*/) || [m.key])[0];
    const name = m.key.slice(pfx.length).replace(/^_/, "").replace(/_/g, " ");
    // A DESCRIPTION HAS NO BOUND, and printing "≤ null" for one (which is what
    // the null/null pair used to render) invents a limit that was deliberately
    // withheld. ")" rather than "–" closes an exclusive top: m3b fails AT 1.0.
    const bound = (m.lo == null && m.hi == null) ? "no bound · described"
      : und ? "awaiting data"
      : (m.lo == null ? (m.hi_exclusive ? "< " : "≤ ") + m.hi
         : m.hi == null ? "≥ " + m.lo
         : m.lo + "–" + m.hi + (m.hi_exclusive ? " (exclusive)" : ""))
        + (open ? " (open)" : "");
    return `<div class="sd-m" title="${(m.test||"").replace(/"/g,"&quot;")}">
      <div class="k">${pfx} ${name}<s> · ${bound}</s></div>
      <div class="v">${m.value == null ? "—" : round(m.value, 3)}</div>
      <div class="roll">${m.rolling == null ? "—" : round(m.rolling, 3)}</div>
      <div class="bar-cell"><div class="sd-bar ${fail?"out":""} ${und?"und":""} ${open?"openend":""}">
        ${clamp == null ? "" : `<i style="left:calc(${(clamp*100).toFixed(1)}% - 1px)"></i>`}
      </div></div>
      <div class="d ${fail?"fail":""}">${m.verdict === "UNDECIDED" ? "—" : m.verdict}</div>
    </div>`;
  }

  function draw(d) {
    if (!d || !d.charter) return;
    $("sd-panel").hidden = false;
    const ch = d.charter, run = d.run || {}, pass = ch.metrics.filter(m => m.verdict === "pass").length;

    const tv = d.turnover || {available: false, admitted: null, candidates: null};

    // ---- what is engaged right now -------------------------------------
    const lv = d.live || {};
    $("sd-win").textContent = lv.window ?? "—";
    $("sd-machine").textContent = lv.machine || "—";
    $("sd-voices").textContent = lv.voices ?? "—";
    const vt = lv.voices_trace || [];
    const vmax = Math.max(1, ...vt);
    $("sd-vtrace").innerHTML = vt.map((v, i) =>
      `<i class="${i === vt.length - 1 ? "now" : ""}" style="height:${Math.max(1, Math.round(v/vmax*22))}px"></i>`).join("");
    const rost = lv.roster || [], newest = rost.length ? rost[0].last : 0;
    $("sd-nmach").textContent = rost.length;
    // Base machines are a fixed repertoire; BRIDGES are composed on the fly when
    // the factory moves between two of them, so the vocabulary grows almost
    // entirely in the transitions rather than the destinations.
    // ---- PITCH: the two axes, each beside the null that could refute it ----
    //
    // The panel carried level, texture, vocabulary and self-ingestion and
    // nothing about pitch, which is what the factory spent 3-5 Sept acquiring
    // and therefore the part most at risk of being overclaimed out loud. Both
    // figures are printed with their null next to them rather than alone,
    // because a share means nothing without the share chance would give.
    (function () {
      // ---- THE ROW MAKES ITSELF IF THE PAGE HAS NOT GOT ONE ---------------
      //
      // The markup lives in a WordPress block that is pasted by hand, and
      // panel.js is served from the relay. So the two drift: this block shipped,
      // the JSON carried the numbers, panel.js looked up #sd-pitch, the $ helper
      // returned its no-op object for a missing element, and the panel rendered
      // NOTHING and reported nothing. Roberto: "where are the metrics?"
      //
      // Silence on a missing element is right for a panel that must never throw
      // in a visitor's browser, and wrong as the only response to markup that is
      // simply out of date. So a row that the page lacks is created next to the
      // gaps block, and re-pasting the block becomes optional rather than a
      // hidden prerequisite for every future addition.
      let host = document.getElementById("sd-pitch");
      if (!host) {
        const panel = document.getElementById("sd-panel");
        const gaps = document.getElementById("sd-gaps");
        if (panel) {
          const row = document.createElement("div");
          row.className = "sd-row";
          const lab = document.createElement("div");
          lab.className = "sd-lab";
          lab.textContent = "pitch · horizontal and vertical · each against a null";
          host = document.createElement("div");
          host.id = "sd-pitch";
          host.style.marginTop = "8px";
          row.appendChild(lab); row.appendChild(host);
          if (gaps && gaps.parentNode === panel) panel.insertBefore(row, gaps);
          else panel.appendChild(row);
        }
      }
      if (!host) return;
      const P = d.pitch;
      if (!P || !P.available) {
        host.innerHTML = '<div class="sd-lab">' +
          ((P && P.reason) || "pitch structure has not reported yet") + '</div>';
        return;
      }
      const rows = [];
      const h = P.horizontal;
      if (h) {
        // z is shown, and shown as the thing that decides the reading. A held
        // share above the shuffled one only means something if the gap is
        // larger than the shuffle's own spread.
        const verdict = h.z > 3 ? "holds pitch more than chance"
                      : h.z < -3 ? "holds pitch LESS than chance"
                      : "indistinguishable from the same pitches in random order";
        rows.push('<div class="sd-lab" style="margin-top:2px">HORIZONTAL · ' +
          h.births + ' voice births</div>' +
          '<div>held on the same pitch <b>' + (100 * h.held_share).toFixed(1) +
          '%</b> · shuffled ' + (100 * h.shuffled_share).toFixed(1) +
          '% · z ' + (h.z > 0 ? "+" : "") + h.z + '</div>' +
          '<div class="sd-lab">median step ' + h.median_step_cents +
          ' cents · ' + verdict + '</div>');
      }
      const v = P.vertical;
      if (v) {
        const inband = Math.abs(v.z) < 2;
        rows.push('<div class="sd-lab" style="margin-top:10px">VERTICAL · ' +
          v.intervals + ' sounding intervals · chord sizes ' +
          (v.chord_sizes || []).join(", ") + '</div>' +
          '<div>on a chord ratio <b>' + (100 * v.on_chord_share).toFixed(1) +
          '%</b> · random ratios ' + (100 * v.random_table_share).toFixed(1) +
          '% ± ' + (100 * v.random_sd).toFixed(1) +
          ' · z ' + (v.z > 0 ? "+" : "") + v.z + '</div>' +
          '<div class="sd-lab">' + (inband
            ? "inside the random band: the vertical layer is not reaching the output"
            : (v.z > 0 ? "above chance: voices are landing on the chord"
                       : "below chance")) + '</div>');
      } else {
        rows.push('<div class="sd-lab" style="margin-top:10px">VERTICAL · ' +
          'no non-unison chord has been drawn yet this run</div>');
      }
      host.innerHTML = rows.join("");
    })();

    const vc = d.vocabulary;
    $("sd-vocab").textContent = vc
      ? `${vc.ever} ever invented · ${vc.bridges} of them bridges`
      : "—";
    $("sd-roster").innerHTML = rost.map(r => {
      // Age since last heard, mapped to ink. A behaviour the factory used two
      // windows ago is nearly black; one it has not returned to in hundreds of
      // windows fades toward the page. The vocabulary and its decay in one view.
      // Age since last heard drives the CELL, not the text: a behaviour used
      // recently sits on dark ground, one the factory has stopped reaching for
      // fades toward the page. Text flips to white on the darkest cells so it
      // stays legible at both ends of the scale.
      const age = Math.max(0, newest - r.last);
      const k = Math.min(1, age / 160);
      const bg = Math.round(190 + k * 56);          // 190 (recent) -> 246 (stale)
      const fg = k < 0.35 ? "#000" : "#8a8a8a";
      const on = r.name === lv.machine_family;
      // THE NUMBER IS THE KEY INTO THE RIBBON. Same map, same run, so a block
      // marked 14 up there is this tile. Machines the ribbon has not shown get
      // no number rather than a misleading one -- the map is populated from the
      // slots, so a machine in the roster but off the ribbon's window range has
      // genuinely not been used inside the span the ribbon covers.
      const num = machNum.has(r.name) ? machNum.get(r.name) : null;
      return `<span class="${on ? "on" : ""}"${on ? "" :
        ` style="background:rgb(${bg},${bg},${bg});color:${fg}"`}
        title="${num ? num + " · " : ""}${r.name} — ${r.count} windows, last heard at window ${r.last}"
        >${num ? `<u>${num}</u> ` : ""}${r.name}</span>`;
    }).join("");

    $("sd-figs").innerHTML = [
      ["windows this run", nfmt(run.windows), "≈12 s each"],
      ["charter metrics held", pass + "/" + ch.metrics.length,
       ch.failing && ch.failing.length ? ch.failing.length + " departing" : "no departures"],
      // NOT the pool headcount. Every layer sits at its cap, because admission
      // works by displacement -- a new grain evicts an incumbent and the total
      // never moves, so it would read 5.4K for the life of the project. What
      // moves is how much the factory has actually taken in.
      ["grains admitted", nfmt(tv.admitted),
       tv.available ? `${(tv.admit_rate*100).toFixed(0)}% of ${nfmt(tv.candidates)} tried` : "—"],
      // P271: a factory that cannot participate in its own charter-writing is
      // Class 1 or 2 automation. It has participated 92 times and been answered
      // none. Putting that in the headline rather than a footnote is the point:
      // the power-sharing this project claims runs one direction so far.
      ["proposals from the factory", nfmt(d.proposals.total),
       d.proposals.adopted + d.proposals.rejected === 0 ? "none answered"
         : `${d.proposals.open} still open`],
    ].map(([l, n, u]) => `<div class="sd-fig"><div class="sd-lab">${l}</div>
        <div class="n">${n}</div><div class="u">${u}</div></div>`).join("");

    $("sd-ed").textContent = ch.edition;
    // A NEVER-TOLERATED FAILURE IS NOT A DEPARTURE. 16 Sept 2026.
    //
    // This counted every failing metric against the tolerance budget and never
    // consulted never_tolerated, so it rendered "departure, 1 of 2 tolerated"
    // while the charter's own state file lists that exact metric as one that
    // can never be tolerated. The panel IS the public claim record, so it was
    // reporting a broken transport as a permitted aesthetic departure.
    //
    // factory_status.py has published ch.never_tolerated since it was written;
    // only the display ignored it.
    const tol = ch.tolerated, failing = ch.failing || [], nf = failing.length;
    const never = (ch.never_tolerated || []).filter(m => failing.includes(m));
    $("sd-verdict").innerHTML = never.length
      ? `<span style="color:var(--focus)">scrapping condition met &mdash; never-tolerated: ${never.join(", ")}</span>`
      : nf === 0 ? "satisfied"
      : nf <= tol ? `departure, ${nf} of ${tol} tolerated`
      : `<span style="color:var(--focus)">scrapping condition met</span>`;
    $("sd-rollhdr").textContent = "last " + ((d.rolling && d.rolling.windows) || "—");
    $("sd-metrics").innerHTML = ch.metrics.map(metricRow).join("");

    // What the readouts fall back to on a browser that will not hand the stream
    // to Web Audio. m2_level is the factory's median master peak per window and
    // m8_in_band its median spectral centroid, both measured on its own output.
    // FACTORY UPTIME, from this run's own start. Separate from the stream
    // figure below, which is the delivery path's and survives a restart.
    if (d.run && d.run.started) {
      const secs = Math.max(0, (d.generated || (Date.now() / 1000)) - d.run.started);
      $("sd-facup").textContent = dur(secs);
      if (mirrorTop) {
        const e = document.getElementById("sd-facup2");
        if (e) e.textContent = dur(secs);
      }
    }

    const rl = d.rolling || {};
    pubPeak = rl.m2_level == null ? null : rl.m2_level;
    pubLevel = pubPeak ? 20 * Math.log10(pubPeak) : null;
    pubCent = rl.m8_in_band == null ? null : rl.m8_in_band;
    showPublished();

    // THE THREE TIMESCALES, from the window log. This is the figure that does
    // not depend on the browser handing over the audio, and it draws for a
    // visitor who has not pressed listen. The published-spectrogram fallback it
    // replaces existed only because the waterfall used to be drawn from server
    // data; the waterfall is now the listener's own audio, so a server-side
    // substitute for it would be a different picture wearing the same frame.
    drawRibbon(d.slots || []);

    const t = d.trace || {peak: []};
    // Feeds the analyser watchdog: what the factory says it has been putting out
    // lately, so a silent browser can be told apart from a silent factory.
    factoryPeakRecent = t.peak.length ? Math.max(...t.peak.slice(-6)) : 0;
    $("sd-tracen").textContent = t.peak.length * (t.windows_per_mark || 1);
    const mx = Math.max(0.01, ...t.peak);
    $("sd-trace").innerHTML = t.peak.map(v => {
      const h = Math.max(1, Math.round((v / mx) * 34));
      // Grey scales with level; the silent windows stay visible as hairlines
      // instead of vanishing, because silence is the m1 failure and hiding it
      // would flatter the run.
      const g = Math.round(210 - (v / mx) * 190);
      return `<i style="height:${h}px;background:rgb(${g},${g},${g})"></i>`;
    }).join("");

    const sig = (d.ews && d.ews.signals) || [];
    $("sd-ews").innerHTML = sig.map(s => {
      if (!s.scales || !s.scales.length) return `<div class="r"><span>${s.metric.replace(/_/g," ")}</span>
        <span class="arrow" style="grid-column:2/4">${s.note || "no data"}</span></div>`;
      const c = s.scales[s.scales.length - 1];
      const dv = c.variance_early > 0 ? c.variance_late / c.variance_early : null;
      const da = c.autocorr_late - c.autocorr_early;
      return `<div class="r"><span>${s.metric.replace(/_/g," ")}</span>
        <span class="arrow">var ×${dv == null ? "—" : dv.toFixed(2)}</span>
        <span class="arrow">ac1 ${da >= 0 ? "+" : ""}${da.toFixed(2)}</span></div>`;
    }).join("") + (() => {
      // The third early-warning signal. Reported as unavailable until 2 Sept,
      // when the factory acquired judges to disagree. Shown WITH its control:
      // the same population on permuted outcomes. Without that number a reader
      // cannot tell structure from a population arguing with itself.
      const e = (d.ews && d.ews.ensemble_disagreement) || {};
      if (!e.available) return `<div class="r" style="color:var(--mute)">
        <span>ensemble disagreement</span>
        <span class="arrow" style="grid-column:2/4">${e.reason || "unavailable"}</span></div>`;
      return `<div class="r"><span>ensemble disagreement</span>
        <span class="arrow">${e.value.toFixed(4)}</span>
        <span class="arrow">vs ${e.control.toFixed(4)} on noise</span></div>`;
    })() + `<div style="color:var(--mute);font-size:10.5px;line-height:1.45;margin-top:9px">
        variance and autocorrelation RISING TOGETHER is the signature of critical
        slowing down, a system taking longer to recover from each perturbation as
        it approaches a fold. Either one moving alone indicates nothing. Reported
        raw, with no threshold attached, because a warning the factory can see and
        optimise toward stops being a warning.
      </div>`;

    const del = d.delivery || {}, kv = [];
    kv.push(["self-ingest weight", d.policy.self_ingest_weight]);
    if (tv.available) {
      // The pre-registered target this whole loop exists to reach. Reporting it
      // plainly, including when it is 1.
      kv.push(["deepest generation", tv.deepest_generation]);
      kv.push(["admitted last hour", tv.admitted_last_hour]);
    }
    (d.corpus.layers || []).forEach(l => kv.push(["pool " + l.layer,
      nfmt(l.grains) + " grains, at cap"]));
    kv.push(["captures ingested", d.corpus.captures_ingested]);
    kv.push(["kernel", (d.kernel.armed ? "armed" : "not armed") + ", ed. " + d.kernel.edition]);
    if (d.judges) {
      const jd = d.judges, best = (jd.realized || [])[0];
      kv.push(["judges", `${jd.population} watching · ${jd.mean_based} mean-based · ${jd.swap_based} swap-based · steering nothing`]);
      kv.push(["judges beat chance by", jd.best_gain_over_base.toFixed(4) +
        (jd.passes_control ? " (passes its null)" : " — FAILS ITS NULL")]);
      if (best) kv.push(["best flag carries", best.lift.toFixed(2) + "× the base rate"]);
    }
    kv.push(["proposals", `${d.proposals.adopted} adopted · ${d.proposals.rejected} refused · ${d.proposals.open} open`]);
    if (del.encoder_drops != null)
      kv.push(["stream splices", del.encoder_drops + " drops, " + del.encoder_restarts + " restarts"]);
    $("sd-kv").innerHTML = kv.map(([k, v]) =>
      `<div class="sd-kv"><b>${k}</b><span>${v == null ? "—" : v}</span></div>`).join("");

    // ---- THE GAPS BLOCK IS OFF THE PAGE, 6 Sept 2026 ------------------------
    //
    // "what this factory does not yet have" listed the principles the system
    // does not meet, read from state.json's `gaps`. Roberto asked for it off the
    // page. That is an editorial decision about what a visitor arriving at a
    // listening page should meet first, and it is his.
    //
    // THE DATA IS NOT REMOVED. factory_status.py still computes `gaps` and
    // state.json still carries it, so the record is intact and public at the
    // endpoint for anyone who reads it. What changed is the page, not the
    // account of the work. If the block ever returns, nothing has to be
    // recomputed to bring it back.
    //
    // REMOVED HERE AND NOT ONLY IN THE MARKUP, because the block is pasted into
    // WordPress by hand and there is no way to know which version of it is live.
    // Editing wordpress_block.html alone would leave the old paste showing the
    // section until Roberto re-pasted, and the last stale-page failure went 1.3
    // hours unnoticed today. So the container is emptied and hidden wherever it
    // is found, and the markup is cleaned for future pastes.
    const gapsEl = $("sd-gaps");
    if (gapsEl) { gapsEl.innerHTML = ""; gapsEl.hidden = true; }
  }

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
  // CONTRAST, SET AGAINST THIS FACTORY AND NOT AGAINST MUSIC IN GENERAL.
  // The delivered stream sits near -42 dBFS with peaks around 0.02, so a linear
  // map spends its whole range in the bottom eighth and the picture came out as
  // pale green washes on white. The gamma lifts quiet material into the visible
  // part of the ramp; the alpha floor stays low but not zero, so the noise floor
  // still disappears into the paper instead of greying the whole canvas.
  const GAMMA = 0.62;
  const alphaAt = u => Math.min(1, Math.max(0, (u - 0.015) * 1.85));
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

  // ONE COLUMN EVERY 50 ms, NOT ONE PER FRAME.
  // At frame rate the canvas holds about 870 columns and therefore about
  // fourteen seconds, which is shorter than a single macro dwell -- so the
  // figure could never show a sustained behaviour sustaining. Throttling to
  // 20 columns a second buys forty-five seconds at the same width, which spans
  // a mid hold and most of a macro one. The analyser still runs at frame rate;
  // only the drawing is decimated.
  const WF_MS = 50;
  let wfLast = 0;

  // One column, scrolled in from the right.
  function wfColumn(f, nyquist) {
    const now = performance.now();
    if (now - wfLast < WF_MS) return;
    wfLast = now;
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
      const u = Math.pow(m / 255, GAMMA);
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
  // A factory-written name carries a ten-digit run stamp -- brgpst2609031253x1 --
  // which is provenance, not identity, and it is the part that gets clipped. The
  // bridge pair and the index are what distinguish two machines on the page; the
  // stamp stays in the tooltip, where there is room for it.
  const shortName = m => m.replace(/^(br[a-z]{4})\d{10}(x\d+)$/, "$1$2");

  // NUMBER THE VOCABULARY, AND PUT THE NUMBER IN THE RIBBON.
  //
  // The first ribbon labelled each block with the machine name, which fits the
  // macro lane and nothing else: mid runs about 35 blocks across the width and
  // micro about 77, so a name of any length is dropped and both fast lanes read
  // as anonymous stripes. Roberto: "with the ribbon system we cannot see what is
  // happening at mid and micro level." A two-digit number fits a nine-pixel
  // block where no name will, and the vocabulary grid below already lists every
  // machine -- so the number is a key into a table that is on the same screen,
  // not an abbreviation the reader has to decode.
  //
  // NUMBERED ON FIRST SIGHT AND NEVER REASSIGNED. Sorting the vocabulary and
  // numbering by position would renumber the whole ribbon the moment the factory
  // writes a machine, and the picture would appear to change while nothing had
  // happened. A machine keeps the number it was given for as long as the page is
  // open, and a new one takes the next free number.
  const machNum = new Map();
  const numOf = m => {
    if (!machNum.has(m)) machNum.set(m, machNum.size + 1);
    return machNum.get(m);
  };
  function drawRibbon(slots) {
    const host = document.getElementById("sd-ribbon");
    if (!host) return;
    // AN EMPTY PAYLOAD IS NOT AN EMPTY RIBBON.
    // This wiped the figure whenever d.slots came back empty, and it comes back
    // empty routinely: the publisher reads the NEWEST window log by mtime, so
    // for the first minute after any factory restart that log has no SLOT lines
    // yet, and a single poll landing in that minute erased a ribbon that was
    // correct. Roberto: "the ribbons sometimes disappear." Keeping the last good
    // render is right in both readings -- the slots really are still what they
    // were, and a figure that blanks itself looks like a fault when it is a
    // gap in polling.
    if (!slots || !slots.length) { return; }
    const last = slots[slots.length - 1].w;
    // Numbers are handed out in WINDOW ORDER, so a low number means the factory
    // reached for that machine early in the run.
    for (const s of slots) numOf(s.m);
    const first = slots[0].w;
    const span = Math.max(1, last - first + 1);
    let html = "";
    for (const lay of LAYERS) {
      // one run per (machine, start window) for this layer, in window order
      const mine = slots.filter(s => s.layer === lay);
      let cells = "";
      for (let i = 0; i < mine.length; i++) {
        const a = mine[i].w, b = (i + 1 < mine.length ? mine[i + 1].w : last + 1);
        const pct = (b - a) / span * 100;
        const n = numOf(mine[i].m);
        // The number goes in at any width; only the NAME needs room. Below about
        // 1.6% the block is narrower than two digits, and there the tooltip is
        // the only reading -- which is still better than the anonymous stripe
        // that was there before.
        const lab = pct > 9 ? `${n} ${shortName(mine[i].m)}` : (pct > 1.6 ? String(n) : "");
        cells += `<i class="sd-rc" style="width:${pct.toFixed(3)}%"` +
                 ` title="${n} · ${mine[i].m} · window ${a} · ${b - a} window${b - a === 1 ? "" : "s"}">${lab}</i>`;
      }
      html += `<div class="sd-rrow"><b>${lay}</b><div class="sd-rlane">${cells}</div></div>`;
    }
    host.innerHTML = html;
  }

  window.__sdRT = () => ({paints: wfPaints, w: wfW, h: wfH,
                          analyser: !!analyser, ctxState: actx && actx.state});

  async function pollState() {
    try { draw(await (await fetch(STATE, {cache: "no-store"})).json()); }
    catch (e) { /* the page keeps working when the panel does not */ }
  }
  async function pollIce() {
    try {
      const d = (await (await fetch(STATUS, {cache: "no-store"})).json()).icestats;
      // THE MOUNT THIS PAGE IS PLAYING, NOT WHICHEVER ICECAST LISTS FIRST.
      //
      // With one mount `source` is an object and `[0]` was harmless. With two it
      // is an array, and taking index 0 would have reported the OTHER factory's
      // listener count and uptime under this factory's name -- wrong numbers
      // wearing a correct label, which is the failure mode this panel exists to
      // avoid. Matched on listenurl so it follows the selector.
      let s = d && d.source;
      if (Array.isArray(s)) {
        const want = FACTORIES[FACTORY].mount;
        s = s.find(x => (x.listenurl || "").endsWith(want)) || null;
      } else if (s && (s.listenurl || "").indexOf(FACTORIES[FACTORY].mount) < 0) {
        // a single source that is NOT ours: this factory is off air
        s = null;
      }

      // Written to both the block's own ids and the pair the adopt() shim makes
      // when the pasted block predates the move to the top.
      const put = (id, v) => {
        $(id).textContent = v;
        if (mirrorTop) { const e = document.getElementById(id + "2"); if (e) e.textContent = v; }
      };
      if (!s) { put("sd-uptime", "—"); put("sd-listeners", "0"); return; }
      put("sd-listeners", s.listeners ?? "—");
      // WHAT THIS NUMBER IS. Icecast's stream_start is when the SOURCE CLIENT
      // last connected, which is the encoder, not the factory and not the
      // splitter. When the factory stops, the FIFO writer closes, the splitter
      // restarts its encoder, and this resets -- so it under-reports a delivery
      // path that has genuinely been continuous, and it is unrelated to the
      // factory's own run, which now has its own figure beside it.
      if (s.stream_start_iso8601) {
        put("sd-uptime", dur((Date.now() - new Date(s.stream_start_iso8601)) / 1000));
      }
    } catch (e) {}
  }
  // 10 s, matched to the factory's own clock. The window is 11.7 s and the
  // machine changes in 94% of windows, so polling at 10 s means the engaged
  // machine is never more than about one window stale. Polling faster would
  // return the same snapshot repeatedly: the publisher writes every 10 s and
  // the underlying quantity does not exist at finer resolution.
  // THE SCRIPT REPAIRS THE MARKUP IT NEEDS.
  // panel.js is fetched from the relay on every load, but the markup around it
  // is a block pasted into WordPress by hand, so the two versions drift apart
  // for as long as it takes someone to re-paste. When this script expects an
  // element the pasted block does not have, the feature attached to it vanishes
  // with no error -- $ returns a harmless dummy for missing ids, which keeps the
  // page alive and keeps the loss invisible.
  //
  // So the two elements added with this change are created here if they are
  // absent. Re-pasting the block is then an improvement to the source of truth
  // and not a precondition for the fix working.
  (function adopt() {
    const root = document.querySelector(".sd-root");
    if (!root) return;
    if (!document.getElementById("sd-rtsrc")) {
      const lab = document.querySelector(".sd-rt .sd-lab");
      if (lab) lab.innerHTML =
        'sounding now · <span id="sd-rtsrc">read from the audio in your browser, at frame rate</span>';
    }
    if (!document.querySelector(".sd-run")) {
      const p = document.createElement("p");
      p.className = "sd-run";
      p.innerHTML = 'stream <span id="sd-uptime2">—</span> · ' +
                    'factory <span id="sd-facup2">—</span> · ' +
                    '<span id="sd-listeners2">—</span> listening now';
      // ABOVE the listen block, matching the block's own order, so a pasted
      // block that predates this change lands the line in the same place
      const listen = root.querySelector(".sd-listen");
      if (listen) root.insertBefore(p, listen); else root.appendChild(p);
      // The old footer copies keep their ids, so both are written; the footer
      // pair is then hidden rather than left contradicting the header.
      const foot = document.querySelector(".sd-foot > div");
      if (foot && /uptime/.test(foot.textContent)) foot.style.display = "none";
      mirrorTop = true;
    }
    // THE RIBBON, BUILT HERE WHEN THE PASTED BLOCK PREDATES IT.
    // panel.js is served with no-cache and updates on the next page load, but
    // the MARKUP lives in the WordPress block and only changes when Roberto
    // pastes it again. A new figure that needs a new element would therefore
    // ship as code that silently does nothing -- drawRibbon returns early on a
    // missing host -- and look like the renderer had failed. Creating the host
    // costs four lines and removes the WordPress step entirely.
    // INSERT AGAINST THE ANCHOR'S OWN PARENT, never against root.
    // The first version did root.insertBefore(lab, rt) with rt found by
    // querySelector, which searches DESCENDANTS -- and .sd-rt is nested two
    // levels down, not a child of .sd-root. insertBefore threw NotFoundError,
    // and because this runs in the same IIFE as the first poll, the throw took
    // pollState with it: the entire panel came up empty on the live page.
    // Roberto, within a minute: "wait all the evals are gone." A cosmetic shim
    // must not be able to remove the evaluation.
    if (!document.getElementById("sd-ribbon")) {
      try {
        const rt = root.querySelector(".sd-rt");
        const lab = document.createElement("div");
        lab.className = "sd-lab";
        lab.style.marginTop = "16px";
        lab.textContent = "three timescales, running together · newest at the right";
        const host = document.createElement("div");
        host.className = "sd-ribbon"; host.id = "sd-ribbon";
        const anchor = rt && rt.parentNode ? rt : null;
        if (anchor) {
          anchor.parentNode.insertBefore(lab, anchor);
          anchor.parentNode.insertBefore(host, anchor);
        } else {
          root.appendChild(lab); root.appendChild(host);
        }
      } catch (e) { /* no ribbon is survivable; a dead panel is not */ }
    }
  })();

  // THE POLL IS NOT DOWNSTREAM OF THE COSMETICS.
  // adopt() above patches markup for blocks pasted before a layout change, and
  // on 3 Sept one line of it threw and took the first poll with it -- the whole
  // panel read empty on the live site while every number behind it was fine.
  // Scheduling the poll out of the current task means no later addition to the
  // shim can reach it, whatever it throws.
  setTimeout(() => { pollState(); pollIce(); }, 0);
  setInterval(pollState, 10000);
  setInterval(pollIce, 30000);
})();
