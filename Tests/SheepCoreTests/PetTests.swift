import Testing
@testable import SheepCore

private let screen = Rect(x: 0, y: 50, width: 1000, height: 700)
private let world = World(screens: [screen])

private func run(_ sheep: inout Pet, in world: World, seconds: Double, seed: UInt64 = 1) {
    var rng = SeededGenerator(seed: seed)
    let dt = 1.0 / 60
    for _ in 0..<Int(seconds / dt) { sheep.step(dt: dt, world: world, rng: &rng) }
}

@Suite struct PhysicsTests {
    @Test func fallsAndLandsOnScreenFloor() {
        var sheep = Pet(x: 500, y: 600)
        run(&sheep, in: world, seconds: 0.2)
        #expect(sheep.behavior == .fall)
        #expect(sheep.y < 600)
        run(&sheep, in: world, seconds: 2)
        #expect(sheep.behavior.isGrounded)
        #expect(sheep.y == screen.minY)
    }

    @Test func landsOnWindowTopInsteadOfFloor() {
        let w = World(screens: [screen], windowTops: [Platform(y: 400, minX: 300, maxX: 700)])
        var sheep = Pet(x: 500, y: 650)
        run(&sheep, in: w, seconds: 2)
        #expect(sheep.y == 400)
    }

    @Test func fallsWhenItsWindowDisappears() {
        let w = World(screens: [screen], windowTops: [Platform(y: 400, minX: 300, maxX: 700)])
        var sheep = Pet(x: 500, y: 400, behavior: .sit, duration: 100)
        run(&sheep, in: w, seconds: 0.5)
        #expect(sheep.y == 400)
        run(&sheep, in: world, seconds: 2)
        #expect(sheep.y == screen.minY)
    }

    @Test func walksOffTheEndOfAWindow() {
        let w = World(screens: [screen], windowTops: [Platform(y: 400, minX: 300, maxX: 520)])
        var sheep = Pet(x: 510, y: 400, facing: .right, behavior: .walk, duration: 100)
        sheep.config.hangChance = 0
        run(&sheep, in: w, seconds: 3)
        #expect(sheep.y == screen.minY)
        #expect(sheep.x > 520)
    }

    @Test func turnsAroundAtScreenEdge() {
        var sheep = Pet(x: 990 - PetConfig().halfWidth, y: screen.minY, facing: .right, behavior: .walk, duration: 100)
        sheep.config.climbChance = 0
        run(&sheep, in: world, seconds: 1)
        #expect(sheep.facing == .left)
        #expect(sheep.x + sheep.config.halfWidth <= screen.maxX)
    }

    @Test func walksAcrossAdjacentMonitorsAtTheSameHeight() {
        let right = Rect(x: 1000, y: 50, width: 800, height: 700)
        let w = World(screens: [screen, right])
        var sheep = Pet(x: 960, y: 50, facing: .right, behavior: .run, duration: 100)
        run(&sheep, in: w, seconds: 2)
        #expect(sheep.x > 1000)
        #expect(sheep.facing == .right)
    }

    @Test func turnsAtMonitorWhoseFloorIsHigher() {
        // Right display's usable area starts higher (e.g. it has the Dock), so the sheep
        // would be inside its Dock area: it turns around instead.
        let right = Rect(x: 1000, y: 120, width: 800, height: 630)
        let w = World(screens: [screen, right])
        var sheep = Pet(x: 960, y: 50, facing: .right, behavior: .walk, duration: 100)
        sheep.config.climbChance = 0
        run(&sheep, in: w, seconds: 2)
        #expect(sheep.facing == .left)
        #expect(sheep.x < 1000)
    }

    @Test func dragAndThrow() {
        var sheep = Pet(x: 500, y: 50, behavior: .stand, duration: 100)
        sheep.beginDrag()
        #expect(sheep.behavior == .dragged)
        sheep.drag(toX: 520, y: 300, dt: 1.0 / 60)
        sheep.drag(toX: 540, y: 310, dt: 1.0 / 60)
        // Dragged sheep ignore gravity.
        run(&sheep, in: world, seconds: 1)
        #expect(sheep.y == 310)
        #expect(sheep.facing == .right)
        sheep.endDrag()
        #expect(sheep.behavior == .fall)
        #expect(sheep.vx > 0)
        run(&sheep, in: world, seconds: 3)
        #expect(sheep.behavior.isGrounded)
        #expect(sheep.x > 540)
        #expect(sheep.y == screen.minY)
    }

    @Test func thrownSheepStaysOnScreen() {
        var sheep = Pet(x: 900, y: 300, behavior: .stand, duration: 100)
        sheep.beginDrag()
        sheep.drag(toX: 960, y: 400, dt: 0.01)
        sheep.endDrag()
        for step in 0..<300 {
            run(&sheep, in: world, seconds: 1.0 / 60, seed: UInt64(step))
            #expect(sheep.x <= screen.maxX && sheep.x >= screen.minX)
            #expect(sheep.y <= screen.maxY)
        }
    }

    @Test func respawnsWhenOutsideAllScreens() {
        var sheep = Pet(x: 5000, y: -5000)
        run(&sheep, in: world, seconds: 0.1)
        #expect(screen.contains(x: sheep.x, y: sheep.y))
    }

    @Test func snapsToWindowThatMovedSlightly() {
        let w = World(screens: [screen], windowTops: [Platform(y: 403, minX: 300, maxX: 700)])
        var sheep = Pet(x: 500, y: 400, behavior: .stand, duration: 100)
        run(&sheep, in: w, seconds: 0.1)
        #expect(sheep.y == 403)
    }
}

@Suite struct StateMachineTests {
    @Test func everyGroundedBehaviorHasSuccessors() {
        for b in Behavior.allCases where b.isGrounded {
            #expect(!Pet.successors(of: b).isEmpty, "\(b) has no successors")
            #expect(Pet.successors(of: b).allSatisfy { $0.isGrounded })
        }
    }

    @Test func sleepOnlyFollowsRestingStates() {
        for b in Behavior.allCases where ![.sit, .yawn, .ride].contains(b) {
            #expect(!Pet.successors(of: b).contains(.sleep))
        }
    }

    @Test func transitionsAfterDurationToAllowedBehavior() {
        var sheep = Pet(x: 500, y: 50, behavior: .stand, duration: 0.5)
        run(&sheep, in: world, seconds: 0.4)
        #expect(sheep.behavior == .stand)
        var rng = SeededGenerator(seed: 7)
        for _ in 0..<10 { sheep.step(dt: 1.0 / 60, world: world, rng: &rng) }
        #expect(Pet.successors(of: .stand).contains(sheep.behavior))
        #expect(sheep.timeInBehavior < 0.2)
    }

    @Test func visitsEveryIdleBehaviorOverTime() {
        var sheep = Pet(x: 500, y: 50, behavior: .stand, duration: 1)
        var seen = Set<Behavior>()
        var rng = SeededGenerator(seed: 42)
        for _ in 0..<(60 * 60 * 20) {
            sheep.step(dt: 1.0 / 60, world: world, rng: &rng)
            seen.insert(sheep.behavior)
            #expect(screen.contains(x: sheep.x, y: sheep.y))
        }
        let idle: Set<Behavior> = [.stand, .walk, .run, .sit, .sleep, .eat, .call]
        #expect(idle.isSubset(of: seen))
    }

    @Test func isDeterministicForASeed() {
        var a = Pet(x: 500, y: 300), b = Pet(x: 500, y: 300)
        run(&a, in: world, seconds: 60, seed: 99)
        run(&b, in: world, seconds: 60, seed: 99)
        #expect(a.x == b.x && a.y == b.y && a.behavior == b.behavior)
    }

    @Test func durationsAreWithinRange() {
        var rng = SeededGenerator(seed: 3)
        var sheep = Pet(x: 500, y: 50, behavior: .stand, duration: 0)
        for _ in 0..<500 {
            sheep.chooseNextBehavior(rng: &rng)
            #expect(Pet.durationRange(for: sheep.behavior).contains(sheep.behaviorDuration))
        }
    }
}

@Suite struct WorldTests {
    @Test func windowTopsAreClippedByWindowsInFront() {
        let front = Rect(x: 400, y: 100, width: 200, height: 400)   // covers x 400-600 up to y 500
        let back = Rect(x: 200, y: 200, width: 600, height: 200)    // top at y 400
        let tops = World.windowTops(frontToBack: [front, back], screens: [screen], headroom: 64)
        #expect(tops.contains(Platform(y: 500, minX: 400, maxX: 600)))
        #expect(tops.contains(Platform(y: 400, minX: 200, maxX: 400)))
        #expect(tops.contains(Platform(y: 400, minX: 600, maxX: 800)))
        #expect(tops.count == 3)
    }

    @Test func windowTopsWithoutHeadroomAreDropped() {
        let maximized = Rect(x: 0, y: 50, width: 1000, height: 690)
        #expect(World.windowTops(frontToBack: [maximized], screens: [screen], headroom: 64).isEmpty)
    }

    @Test func tinySegmentsAreDropped() {
        let narrow = Rect(x: 100, y: 100, width: 10, height: 100)
        #expect(World.windowTops(frontToBack: [narrow], screens: [screen], headroom: 64).isEmpty)
    }
}

@Suite struct ArtTests {
    @Test func everyFrameRendersSomething() {
        for b in Behavior.allCases where b != .finale { // finales end blank on purpose
            let frames = PetArt.frames(for: b)
            #expect(!frames.isEmpty)
            for pose in frames {
                let canvas = PetArt.render(pose)
                #expect(canvas.width == PetArt.width && canvas.height == PetArt.height)
                #expect(!canvas.isBlank)
            }
        }
    }

    @Test func standingSheepTouchesTheGround() {
        let canvas = PetArt.render(Pose())
        #expect((0..<canvas.width).contains { canvas.isSolid($0, PetArt.groundRow - 1) })
        #expect(!(0..<canvas.width).contains { canvas.isSolid($0, PetArt.groundRow + 1) })
    }

    @Test func walkAnimationChangesOverTime() {
        let fps = PetArt.framesPerSecond(.walk)
        let poses = Set((0..<12).map { PetArt.pose(for: .walk, time: (Double($0) + 0.5) / fps) })
        #expect(poses.count == PetArt.frames(for: .walk).count)
        #expect(poses.count >= 6)
    }

    @Test func blinksBrieflyAndOutOfSyncByPhase() {
        let samples = (0..<370).map { Double($0) / 100 }
        let closed = samples.filter { PetArt.pose(for: .stand, time: $0).eyes == .closed }.count
        #expect(closed > 0 && closed < 30)
        #expect(PetArt.pose(for: .stand, time: 3.6).eyes == .closed)
        #expect(PetArt.pose(for: .stand, time: 3.6, phase: 0.5).eyes == .open)
        // Sleeping eyes stay closed; falling eyes stay wide.
        #expect(PetArt.pose(for: .fall, time: 3.6).eyes == .wide)
    }

    @Test func shadowIsTranslucentAndOnlyWhenGrounded() {
        let standing = PetArt.render(PetArt.pose(for: .stand, time: 0))
        #expect(standing.hasTranslucent)
        #expect(!PetArt.render(PetArt.pose(for: .fall, time: 0)).hasTranslucent)
        #expect(!PetArt.render(PetArt.pose(for: .dragged, time: 0)).hasTranslucent)
    }

    @Test func petSitsAtTheBottomCenterOfTheSprite() {
        let c = PetArt.render(Pose())
        let solidColumns = (0..<c.width).filter { x in (0..<c.height).contains { PetArt.isSolid(c[x, $0]) } }
        let mid = Double(solidColumns.first! + solidColumns.last!) / 2
        #expect(abs(mid - Double(c.width) / 2) <= 4)
        // Plenty of headroom above the pet for effects.
        #expect((0..<12).allSatisfy { y in (0..<c.width).allSatisfy { c[$0, y] == 0 } })
    }
}
