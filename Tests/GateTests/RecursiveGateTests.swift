import Testing
import Gate

actor ReentrantSensitiveState {
	var value = 42

	func doThing() async throws {
		try #require(self.value == 42)
		self.value = 0
		try await Task.sleep(nanoseconds: 1_000_000)
		try #require(self.value == 0)
		self.value = 42
	}
}

actor RecursiveReentrantActor {
	let state = ReentrantSensitiveState()
	let gate = AsyncRecursiveGate()

	func doThing() async throws {
		try await gate.withGate {
			try await state.doThing()
		}
	}
}

actor TwoGateRecursiveReentrantActor {
	let state = ReentrantSensitiveState()
	let gate1 = AsyncRecursiveGate()
	let gate2 = AsyncRecursiveGate()

	func holdBothGates(with block: () async throws -> Void) async rethrows {
		try await gate1.withGate {
			try await gate2.withGate {
				try await block()
			}
		}
	}

	func doThing() async throws {
		try await holdBothGates {
			try await state.doThing()
		}
	}
}

struct RecursiveGateTests {
	@Test
	func recursion() async {
		let gate = AsyncRecursiveGate()

		#expect(gate.isGated == false)

		await gate.withGate {
			#expect(gate.isGated)

			await gate.withGate {
				#expect(gate.isGated)
			}

			#expect(gate.isGated)
		}
		
		#expect(gate.isGated == false)
	}

	@Test
	func mulitpleNestedGates() async {
		let gate1 = AsyncRecursiveGate()
		let gate2 = AsyncRecursiveGate()

		await gate1.withGate {
			await gate2.withGate {
				#expect(gate1.isGated)
				#expect(gate2.isGated)
			}
		}
	}

	@Test
	func serializesWithRecursiveGate() async throws {
		let actor = RecursiveReentrantActor()

		try await withThrowingTaskGroup { group in
			for _ in 0..<1000 {
				group.addTask {
					try await actor.doThing()
				}
			}

			for try await _ in group {}
		}
	}

	@Test
	func serializesWithTwoGates() async throws {
		let actor = TwoGateRecursiveReentrantActor()

		try await withThrowingTaskGroup { group in
			for _ in 0..<1000 {
				group.addTask {
					try await actor.doThing()
				}
			}

			for try await _ in group {}
		}
	}
}
