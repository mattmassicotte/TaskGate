import Testing
import TaskGate

actor ReentrantActor {
	let state = ReentrantSensitiveState()
	let gate = AsyncGate()

	func doThingUsingWithGate() async throws {
		try await gate.withGate {
			try await state.doThing()
		}
	}
}

struct AsyncGateTests {
	@Test
	func serializes() async throws {
		let actor = ReentrantActor()

		try await withThrowingTaskGroup { group in
			for _ in 0..<1000 {
				group.addTask {
					try await actor.doThingUsingWithGate()
				}
			}

			for try await _ in group {}
		}
	}

	@Test
	func checkGateWithGate() async throws {
		let gate = AsyncGate()

		#expect(gate.isGated == false)
		await gate.withGate {
			#expect(gate.isGated == true)
		}
		#expect(gate.isGated == false)
	}

	@Test
	@MainActor
	func cancelWhileHoldingGate() async throws {
		let gate = AsyncGate()

		let t = Task {
			try await gate.withGate {
				try await Task.sleep(nanoseconds: 5_000_000)
			}
		}

		await #expect(throws: CancellationError.self) {
			t.cancel()
			
			try await t.value
		}

		#expect(gate.isGated == false)
	}
}
