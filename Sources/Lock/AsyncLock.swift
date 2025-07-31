public final class AsyncLock {
	private enum State {
		typealias Continuation = CheckedContinuation<Void, Never>

		case unlocked
		case locked([Continuation])

		mutating func addContinuation(_ continuation: Continuation) {
			guard case var .locked(continuations) = self else {
				fatalError("Continuations cannot be added when unlocked")
			}

			continuations.append(continuation)

			self = .locked(continuations)
		}

		mutating func resumeNextContinuation() {
			guard case var .locked(continuations) = self else {
				fatalError("No continuations to resume")
			}

			if continuations.isEmpty {
				self = .unlocked
				return
			}

			let continuation = continuations.removeFirst()

			continuation.resume()

			self = .locked(continuations)
		}
	}

	private var state = State.unlocked

	public init() {
	}

	public func lock(isolation: isolated (any Actor)? = #isolation) async {
		switch state {
		case .unlocked:
			self.state = .locked([])
		case .locked:
			await withCheckedContinuation { continuation in
				state.addContinuation(continuation)
			}
		}
	}

	public func unlock() {
		state.resumeNextContinuation()
	}

	public func withLock<T: Sendable, E: Error>(
		isolation: isolated (any Actor)? = #isolation,
		_ block: @isolated(any) () async throws(E) -> T
	) async throws(E) -> T {
		await lock()

		do {
			let value = try await block()

			unlock()

			return value
		} catch {
			unlock()

			throw error
		}
	}

	public var isLocked: Bool {
		get {
			switch state {
			case .unlocked:
				false
			case .locked:
				true
			}
		}
	}
}
