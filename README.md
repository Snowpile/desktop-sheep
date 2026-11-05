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
- Optional **Sounds** (off by default; menu or Settings): short original sounds synthesized in
  code: bleat, meow, bark, squeak, chirp, thuds, and pops, poofs and booms for the finale.
- **Launch at Login** menu toggle (uses `SMAppService`; only in the bundled .app, and macOS may
  ask you to allow it under System Settings › General › Login Items).
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
- Pets notice the mouse cursor: idle pets look at it, now and then one chases it, and a fast
  swipe nearby startles them into a jump and a dash away. **⌥-click anywhere** (or menu
  **Drop a Treat**) drops a treat that falls onto the nearest surface; the closest pet runs over
  and eats it.
- Gravity, landing, throwing, turning around at screen edges, or (optional setting) walking off
  the outer edge of the screen and leaving, with a chance of a new pet showing up later.
- Multi-monitor aware: sheep cross between displays that line up, and turn back otherwise.
- Random behavior state machine: walk, run, sit, sleep, eat, call (bleat/meow/bark…, visual only),
  dig, chase butterflies, yawn, trip and tumble.
- Climbing: pets sometimes climb up the side of a window onto its top, or up a screen edge and
  drop back down; walking off a window, they may hang from its edge before letting go.
- Pets notice each other: they bump and turn or stop to nuzzle, chase and tag, fall into
  follow-the-leader lines, play-fight, stack up on each other's backs (and ride along), and yawns
  spread. Every behavior can be switched off in Settings.
- Pixel art is drawn at runtime from code: each animal is a small rig of shapes
  (`Sources/SheepCore/RigAnimals.swift`), posed per frame and rasterized as shaded 64x64 pixel
  art (`PixelStyle.swift`), shown at 1.5x. Props and effects are layered on top.
- `Sources/SheepCore` – pure Swift, no AppKit: world geometry (screens, window tops), physics,
  the behavior state machine, and the pixel-art renderer. Unit tested.
- `Sources/DesktopSheep` – the AppKit shell: one small floating panel per sheep, the menu-bar
  item, mouse dragging and click-through, and the window scanner.
- `scripts/bundle.sh` – wraps the release binary into an `.app` with `LSUIElement`.
- `Sources/ArtLab` – `swift run ArtLab` renders preview sheets into `docs/previews`, including
  an alternative smooth vector style (Core Graphics) drawn from the same rig.

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
