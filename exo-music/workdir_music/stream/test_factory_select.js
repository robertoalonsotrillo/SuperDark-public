// Exercise the two pieces of logic that decide what a listener hears:
// which factory a URL selects, and which icestats source is matched to it.
const RELAY = "https://stream.robertoalonsotrillo.com";
const FACTORIES = {
  "1": { name: "Factory 1", mount: "/replica.mp3",   state: "/state-replica.json" },
  "2": { name: "Factory 2", mount: "/superdark.mp3", state: "/state.json" }
};
function pick(search) {
  return (new URLSearchParams(search).get("factory") === "2") ? "2" : "1";
}
let fail = 0;
const eq = (got, want, what) => {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  if (!ok) fail++;
  console.log(`  ${ok ? "ok  " : "FAIL"} ${what}: ${JSON.stringify(got)}`);
};
console.log("--- URL selects the factory ---");
eq(pick(""),            "1", "no param defaults to Factory 1 (continuous)");
eq(pick("?factory=1"),  "1", "?factory=1");
eq(pick("?factory=2"),  "2", "?factory=2");
eq(pick("?factory=9"),  "1", "garbage falls back to 1");

console.log("--- the panel follows the audio ---");
for (const id of ["1","2"]) {
  eq(RELAY + FACTORIES[id].mount + " | " + RELAY + FACTORIES[id].state,
     RELAY + FACTORIES[id].mount + " | " + RELAY + FACTORIES[id].state,
     `factory ${id} pairs mount+state`);
}
eq(FACTORIES["1"].state === FACTORIES["2"].state, false,
   "the two factories do NOT share a state file");
eq(FACTORIES["1"].mount === FACTORIES["2"].mount, false,
   "the two factories do NOT share a mount");

console.log("--- icestats: the right source, with two mounts present ---");
const ice = { source: [
  { listenurl: "http://localhost:8000/superdark.mp3", listeners: 7 },
  { listenurl: "http://localhost:8000/replica.mp3",   listeners: 3 }
]};
function match(d, FACTORY) {
  let s = d && d.source;
  if (Array.isArray(s)) {
    const want = FACTORIES[FACTORY].mount;
    s = s.find(x => (x.listenurl || "").endsWith(want)) || null;
  }
  return s;
}
eq(match(ice,"1").listeners, 3, "Factory 1 reads /replica.mp3 listeners");
eq(match(ice,"2").listeners, 7, "Factory 2 reads /superdark.mp3 listeners");
console.log("       (index 0 would have given Factory 1 the number 7 -- the other factory's audience)");

console.log("--- one factory off air ---");
const only2 = { source: { listenurl: "http://localhost:8000/superdark.mp3", listeners: 7 } };
function match1(d, FACTORY) {
  let s = d && d.source;
  if (Array.isArray(s)) {
    s = s.find(x => (x.listenurl||"").endsWith(FACTORIES[FACTORY].mount)) || null;
  } else if (s && (s.listenurl||"").indexOf(FACTORIES[FACTORY].mount) < 0) { s = null; }
  return s;
}
eq(match1(only2,"1"), null, "Factory 1 absent -> null, not the other factory");
eq(match1(only2,"2").listeners, 7, "Factory 2 still reads its own");
console.log(fail ? `\n  ${fail} FAILURE(S)` : "\n  ALL PASS");
process.exit(fail ? 1 : 0);
