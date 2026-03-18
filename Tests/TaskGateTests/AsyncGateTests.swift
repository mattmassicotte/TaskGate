import Testing
import TaskGate

actor ReentrantActor {
	let state = ReentrantSensitiveState()
	let gate = AsyncGate()

	func doThingUsingWithGate(_ body: () async throws -> Void) async throws {
		try await gate.withGate {
			try await body()
		}
	}

	func accessState() async throws {
		try await doThingUsingWithGate {
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
					try await actor.accessState()
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
				try await Task.sleep(nanoseconds: 5_000_000_000)
			}
		}

		await #expect(throws: CancellationError.self) {
			t.cancel()
			
			try await t.value
		}

		#expect(gate.isGated == false)
	}

#if swift(>=6.2)
	@Test
	@available(macOS 26.0, macCatalyst 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *)
	func escalatingPriorities() async throws {
		let actor = ReentrantActor()
		var tasks: [Task<Void, any Error>] = []
		let testPriority = Task.currentPriority

		for i in 0..<10 {
			let t = Task.immediate(priority: .low) {
				#expect(Task.currentPriority == .low, "no escalation possible yet \(i)")

				try await actor.doThingUsingWithGate {
					// we may or may not have been escalated at this point
					#expect(Task.currentPriority >= .low, "cannot have lower priority at this point \(i)")

					// This is not ideal synchronization. It is possible for a task
					// to complete before the escalation happens. But I cannot come up with a better way.
					try await Task.sleep(for: .milliseconds(1000))

					#expect(Task.currentPriority == testPriority, "must be escalated here \(i)")
				}
			}

			tasks.append(t)
		}

		for t in tasks {
			try await t.value
		}
	}
#endif
}
