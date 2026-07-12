# Always Ready — talk deck

Plain white-on-black, terminal-aesthetic slide deck for the `ready` talk.
Self-contained single file, no dependencies.

## Present

Open `index.html` in any browser.

- `→` / `space` / click-right — next
- `←` / click-left — back
- `f` — fullscreen
- `Home` / `End` — first / last
- deep-link to a slide with `#12` in the URL

## Shape (37 slides ≈ 30 min)

Paced for ~30 min *with* a live demo. Slides are sparse on purpose — the
narrative lives in your mouth, not on the screen.

| slides | beat | ~time |
|---|---|---|
| 1–3 | hook: `ri TCPServer`, "where did the second go?" | 2 min |
| 4–9 | the four layers, ending on the real waterfall | 6 min |
| 10–11 | it happens every time — `ls`→colorls is the daily pain | 2 min |
| 12–13 | the idea: run all but the last layer ahead of time, keep it hot | 1 min |
| 14–18 | Spring (peaked in high school) → why ready ≠ Spring → the loved cousins (emacs daemon, LSP) | 4 min |
| 19–22 | the `by` discovery, Jeremy Evans, "load a gem without loading rubygems" | 4 min |
| 23–26 | the two taxes (resolver / code-loading) and why ready needs both levers | 3 min |
| 27–31 | **LIVE DEMO** — readyfile → `ready up` → new shell → type `irb`/`ls`, instant | 4 min |
| 32–33 | the numbers: cold→hot, heavier tools win bigger | 2 min |
| 34–35 | bootsnap objection + the honest floor (the `by` client is still a Ruby boot) | 1.5 min |
| 36–37 | close + hallway (no Q&A) | 0.5 min |

## Cues you asked to keep

- **Slide 19** — the "Jeremy Evans, speaking next door / the one you picked me
  over this morning" line. Deliver it live; the slide just names the gem.
- **Slide 27–31** — swap the slides for a real terminal if the demo cooperates;
  they're a fallback if it doesn't. Lead the demo with **colorls-as-`ls`**, the
  high-frequency reflex, not `ri`.
- **Slide 14** — the `DISABLE_SPRING=1 ⭐812` line stands in for the Stack
  Overflow screenshots.

## Numbers

The cold/hot figures (slides 9, 32, 33) are real measurements from the layered
benchmark (`rake bench`) on a dev box: resolver tax ~45 ms fixed, dependency
activation variable (ri ~37 ms → ronin ~343 ms), hot dispatch ~20–40 ms. Re-run
`BENCH_EXE=… rake bench` on your presenting machine and update them so "my
machine" is literally true on stage.
