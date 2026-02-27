public final class AsyncGate {
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

	private func lock() async {
		switch state {
		case .unlocked:
			self.state = .locked([])
		case .locked:
			await withCheckedContinuation { continuation in
				state.addContinuation(continuation)
			}
		}
	}

	private func unlock() {
		state.resumeNextContinuation()
	}

	public func withGate<Result, Failure>(
		_ body: () async throws(Failure) -> sending Result
	) async throws(Failure) -> sending Result where Failure: Error, Result: ~Copyable {
		await lock()

		do {
			let value = try await body()

			unlock()

			return value
		} catch {
			unlock()

			throw error
		}
	}

	public var isGated: Bool {
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
