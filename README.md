# foxclick

A focus-independent autoclicker for a single XWayland game. For reliable
clicking while the game is unfocused, run the game inside Gamescope.

Ordinary Linux autoclickers (xclicker, xdotool loops, ydotool) inject input at a
global level: the click lands in *whatever* window is focused. On Wayland you
can't tell them "only click that one background window", so the moment you switch
to another window the clicks follow you there — you can't touch anything else on
the machine while the autoclicker runs.

`foxclick` sends synthetic clicks to **one specific X window, addressed by id**
(`xdotool --window`). Whether an unfocused game accepts those events depends on
the game and XWayland setup. Gamescope's nested X display keeps the game as the
input target when you switch to another desktop window, and is the recommended
setup for the alt-tab use case. Direct XWayland mode is best-effort and may stop
working when the game loses focus. Regular clicking does not move the pointer;
position-targeted clicking moves it to the saved location before each click.

It was written for repetitive hold-to-work actions in
[Foxhole](https://store.steampowered.com/app/505460/Foxhole/) (building, digging),
but nothing in it is Foxhole-specific — point `WINDOW_CLASS` at any XWayland game.

> **Recommended:** run Foxhole through [Gamescope](https://github.com/ValveSoftware/gamescope)
> so clicks continue while the game is unfocused. Without Gamescope, behavior
> depends on whether the game accepts synthetic input while unfocused.

## How it works

```
        your Wayland session
┌─────────────────────────────────────────┐
│  browser / Discord / terminal  (focused) │  ← your real keyboard + mouse
│                                          │
│  the game  (XWayland window, unfocused)  │  ← foxclick's clicks, by window id
└──────────────▲───────────────────────────┘
               │
   foxclick ── xdotool click --window <game id> ──┘
```

`xdotool click --window <id>` delivers a synthetic `ButtonPress`/`ButtonRelease`
via `XSendEvent` to the selected window. This selects the event destination; it
does not guarantee that an unfocused game will accept the event. Gamescope's
nested display is recommended when clicks must continue after alt-tab. Regular
clicking doesn't move your pointer; position-targeted clicking moves it to the
saved location in the game window before each click.

foxclick finds the game window by X class (and optionally name), picking the
largest matching window so it ignores the game's tiny helper/IME/tooltip windows.

## Requirements

- A Linux desktop session with access to the game's X display. Gamescope is
  recommended for reliable background clicking; direct XWayland use is
  best-effort when the game is unfocused.
- [`gamescope`](https://github.com/ValveSoftware/gamescope) for the recommended
  setup.
- [`xdotool`](https://archlinux.org/packages/extra/x86_64/xdotool/)
- `bash`, `awk`, coreutils, `setsid` (util-linux) — all standard.
- Optional: `notify-send` (libnotify) for desktop notifications.

```sh
sudo pacman -S gamescope xdotool # Arch / CachyOS / Omarchy
```

## Install

```sh
git clone https://github.com/erlendrosok/foxclick
cd foxclick
./install.sh
```

The installer assigns KDE shortcuts for toggling (`Meta+X`), capturing the
pointer position (`Meta+H`), and starting at that saved position (`Meta+C`).
Override them with `FOXCLICK_KEY`, `FOXCLICK_CAPTURE_KEY`, and
`FOXCLICK_CLICK_KEY`; set an individual variable to `none` to skip its shortcut.
On other desktops, bind the commands manually as described below.

`install.sh` copies:

| file | destination |
|---|---|
| `foxclick` | `~/.local/bin/foxclick` |
| `config.example` | `~/.config/foxclick/config` (only if missing) |
| generated `.desktop` entries | `~/.local/share/applications/foxclick*.desktop` |

On KDE it also registers global shortcuts. Everywhere else you bind the keys
yourself — see below.

## Global shortcut

Bind `foxclick toggle` to stop the regular autoclicker and `foxclick capture`
and `foxclick click` to select and use a screen position while in-game.

| environment | where |
|---|---|
| Hyprland | `bind = SUPER, A, exec, foxclick toggle`; `bind = SUPER, H, exec, foxclick capture`; `bind = SUPER, C, exec, foxclick click` (Omarchy: `o.bind` in `~/.config/hypr/bindings.lua`) |
| KDE Plasma | `install.sh` registers Meta+X, Meta+H, and Meta+C; change them in *System Settings → Shortcuts* |
| GNOME | Settings → Keyboard → *Custom Shortcuts*, commands `foxclick toggle`, `foxclick capture`, and `foxclick click` |
| Sway / i3 | `bindsym $mod+a exec foxclick toggle`; `bindsym $mod+h exec foxclick capture`; `bindsym $mod+c exec foxclick click` |
| niri | `Mod+A { spawn "foxclick" "toggle"; }`; `Mod+H { spawn "foxclick" "capture"; }`; `Mod+C { spawn "foxclick" "click"; }` |

Pick keys the game doesn't use. The shortcuts need to reach your compositor
while the game is focused — `Super`/`Meta` combos usually do; if not, run the
commands from a terminal on your other monitor.

## Set up the game

In Steam → game → *Properties* → *Launch Options*, run the game through
Gamescope, for example:

```
gamescope -f -- %command%
```

Use the Gamescope options appropriate for your display and setup. If you choose
to run without Gamescope, clicks may not be accepted while the game is unfocused.

## Usage

With the game running:

```sh
foxclick calibrate   # show the detected game window + fire 5 test clicks
foxclick start       # start
foxclick stop        # stop
foxclick toggle      # start if stopped, stop if running  (bind this to a key)
foxclick capture     # save the current pointer position relative to the game window
foxclick click       # start the configured click/hold action at that saved position
foxclick status      # running state + last-run log
foxclick log         # just the diagnostic log
```

Typical flow: put the pointer over the desired spot in-game and press the
capture key; press the click key to start the configured action at that spot.
The click action honors `MODE`, `CPS`, `JITTER`, `BUTTON`, `REASSERT`, and
`CLEARMODS`. Press the toggle/stop key to stop it. The position is saved relative
to the game window, so it remains selected if that window moves.

foxclick auto-stops if the game window disappears.

## Configuration

`~/.config/foxclick/config` (plain shell, sourced):

| key | default | meaning |
|---|---|---|
| `MODE` | `click` | `click` = repeated click events; `hold` = press and hold the button |
| `CPS` | `12` | clicks per second (click mode) |
| `JITTER` | `15` | ± percent random variation on the interval; `0` = perfectly steady |
| `BUTTON` | `1` | X button — `1` left, `2` middle, `3` right |
| Position target | — | `capture` saves the pointer position within the game window; `click` starts the normal configured action at that position |
| `REASSERT` | `1` | hold mode: re-send the press every tick so a dropped press recovers |
| `WINDOW_CLASS` | `steam_app_505460` | X class of the game window (Foxhole = its Steam appid) |
| `WINDOW_NAME` | *(empty)* | optional extra filter: the window name must match this regex |
| `X_DISPLAY` | *(empty)* | force the X display (e.g. `:0`); empty = autodetect |
| `CLEARMODS` | `0` | send a modifier-release to the game window before each click — enable only if a key you physically hold (Alt for push-to-talk) is turning clicks into modified clicks in-game |
| `MAX_SECONDS` | `0` | safety auto-stop after N seconds; `0` = no limit |

Changes take effect on the next `start`/`toggle`/`click` — there's no daemon.

## Troubleshooting

- **`foxclick log`** prints what the last run did, including raw `xdotool` errors.
- **"game window not found"**: the game isn't running, its window isn't exposed
  on an accessible X display, or its window class isn't `steam_app_505460` — run
  `foxclick calibrate`, or set `WINDOW_CLASS` / `WINDOW_NAME` to what
  `xdotool search --name .` shows.
- **Clicks stop when you alt-tab away from the game**: this can happen when
  running without Gamescope because the game may reject synthetic events while
  unfocused. Run the game through Gamescope for the recommended background-click
  behavior.
- **Clicks land in the wrong place in-game**: use `foxclick capture` with the
  pointer over the desired location, then `foxclick click`. The ordinary `start`
  and `toggle` commands continue to use the current pointer position.
- **One click then nothing** in `hold` mode: keep `REASSERT=1` (default), or use
  `MODE=click`.
- **Right-click (or another button) dies in-game after using foxclick**: `stop`
  releases buttons 1/2/3 on the game window and every `start` begins from a clean
  slate, so toggling clears it.
- **The toggle key does nothing over the game**: some compositors don't deliver
  global shortcuts while a fullscreen game is focused. Run `foxclick toggle` from
  a terminal on your other monitor, or rebind.

## Caveats

- Injecting automated input may violate a game's terms of service or code of
  conduct. That's on you.
- Anti-cheat that inspects the X server or input devices may notice. This uses
  the same `XSendEvent` mechanism as many X automation tools — no attempt is made
  to hide anything.

## License

MIT — see [LICENSE](LICENSE).
