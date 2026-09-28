// Intercepts Pkill.play so Handler's own machine methods can be run offline.
// The pattern is captured instead of scheduled; nothing else about Archon changes.
+ Pkill {
    play { |argClock, protoEvent, quant|
        ~capturedPattern = this;
        ^nil
    }
}

// The generated machines (dr, pu, hm, me) wrap their Pkills in Ppar to sound
// several layers at once. Without this second hook Ppar.play would schedule
// against a server that does not exist offline and capture nothing, so those
// machines would render as silence. That is the pitchcps failure mode: a
// machine that is selected, reports OK, and produces no audio.
+ Ppar {
    play { |argClock, protoEvent, quant|
        ~capturedPattern = this;
        ^nil
    }
}
