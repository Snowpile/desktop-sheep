# Desktop Sheep

A small pixel-art sheep (or cat, dog, bunny or red panda) that lives on your macOS desktop,
inspired by classic 90s desktop pets. All art and code are original.

The sheep wanders along the bottom of the screen (just above the Dock) and along the top edges of
your windows. It walks, runs, sits, falls asleep, grazes and bleats, and tumbles down when the
window it was standing on moves or closes. Pick it up with the mouse and drop or throw it anywhere.

## Features

- Transparent, borderless, always-on-top sheep; clicks pass through everywhere except the sheep.
- Visible on all Spaces, no Dock icon. A menu-bar sheep offers **Add Pet**, **Remove Pet**,
  **Animal (All Pets)**, **Walk on Windows**, **Settings…** and **Quit**.
- Five animals with their own flavor: the sheep bleats and grazes, the cat meows and eats fish,
  the dog barks and chews a bone, the bunny hops and nibbles a carrot, the red panda chirps and
  munches bamboo. Pick one for all pets (or **Mixed**) from the menu or Settings; right-click a
  single pet to change just that one.
- Settings window: animal, number of pets, entry style, finale style, walk on windows,
  walk off screen, speed, and which idle behaviors
  are allowed. Choices are saved in UserDefaults (`com.snowpile.desktop-sheep`) and restored on launch.
- New pets arrive in style (menu **New Pets Arrive By** or Settings): dropped from the top,
  drifting down on a parachute, as a flaming meteor that lands with a dazed thud, by jetpack from
  the side of the screen, or a surprise pick.
- **Grand Finale** (menu, with a confirmation): after a 3-2-1 countdown over their heads, all
  pets go at once: burn to a pile of ash that blows away, explode into confetti, vanish in a puff,
  float away on balloons, get beamed up, shrink to nothing, or a surprise mix. Afterwards the menu
  offers **Bring Back Pets**.
- Gravity, landing, throwing, turning around at screen edges, or (optional setting) walking off
  the outer edge of the screen and leaving, with a chance of a new pet showing up later.
- Multi-monitor aware: sheep cross between displays that line up, and turn back otherwise.
- Random behavior state machine: walk, run, sit, sleep, eat, call (bleat/meow/bark…, visual only).
- Pixel art is drawn at runtime from code (`Sources/SheepCore/SheepArt.swift`): a 40x32 pet in a
  48x48 sprite (room for effects), shown at 2x, with blinking, ear flicks, a wagging tail,
  wool highlights and a soft ground shadow.

## Requirements

macOS 13 or later, Swift 6 toolchain. Xcode is not required; the Command Line Tools are enough.

## Download

Grab `Desktop-Sheep-vX.Y.Z.zip` from the [latest release](https://github.com/Snowpile/desktop-sheep/releases/latest),
unzip it and move **Desktop Sheep.app** to Applications. The app is ad-hoc signed, not notarized,
so the first time macOS will refuse to open it: right-click the app, choose **Open**, then **Open**
again (or run `xattr -dr com.apple.quarantine "/Applications/Desktop Sheep.app"`).

Releases are built by GitHub Actions when a `v*` tag is pushed; every push and pull request is
built and tested on a macOS runner.

## Build and run

```sh
swift build
swift run DesktopSheep              # one sheep
swift run DesktopSheep --count 3    # a small flock (session only; nothing is saved)

swift test                          # physics, state machine, window-edge and sprite tests

scripts/bundle.sh                   # builds dist/Desktop Sheep.app (release, ad-hoc signed)
open "dist/Desktop Sheep.app"
```

Quit from the menu-bar sheep, or `pkill -f DesktopSheep`.

`VERSION=1.2.3 scripts/bundle.sh` sets the app's version (defaults to 0.1.0).

## Permissions

None are needed. Window positions come from `CGWindowListCopyWindowInfo`, which returns window
bounds without Screen Recording permission (only window titles require it, and they are not used).
No Accessibility permission is used: dragging works through the sheep's own window.

## Layout

- `Sources/SheepCore` – pure Swift, no AppKit: world geometry (screens, window tops), physics,
  the behavior state machine, and the pixel-art renderer. Unit tested.
- `Sources/DesktopSheep` – the AppKit shell: one small floating panel per sheep, the menu-bar
  item, mouse dragging and click-through, and the window scanner.
- `scripts/bundle.sh` – wraps the release binary into an `.app` with `LSUIElement`.

## Known limitations

- Window edges are re-read about twice a second, so a sheep on a fast-moving window may fall off.
- Windows on other Spaces are ignored; sheep only use windows on the current Space.
- Fully maximized windows have no room above them, so sheep walk on the Dock-level floor instead.
- Click-through is decided by polling the mouse position, so the very edge of the sprite can
  occasionally miss a click.

## Note on Swift Testing with Command Line Tools only

Without Xcode, SwiftPM does not find the Swift Testing macro plugin by itself. `Package.swift`
adds `-plugin-path` for the Command Line Tools location when it exists, so `swift test` works
either way.

## License

MIT, see [LICENSE](LICENSE).
