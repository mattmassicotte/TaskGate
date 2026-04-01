import Foundation

public final class AsyncGate {
	private enum State {
		typealias Continuation = CheckedContinuation<Void, Never>

		case unlocked
		case locked(PendingContinuationQueue)

		var pending: PendingContinuationQueue? {
			switch self {
			case .unlocked:
				return nil
			case .locked(let pending):
				return pending
			}
		}
	}

	private let lock: NSLock = NSLock()
	private var state: State = .unlocked

	public init() {
	}

	deinit {
		switch state {
		case .unlocked:
			break
		case .locked:
			preconditionFailure("deinit called while gate is active")
		}
	}

	private func takeLock() {
		lock.lock()
	}

	private func releaseLock() {
		lock.unlock()
	}

	private func closeGate() async {
		takeLock()

		switch state {
		case .unlocked:
			self.state = .locked(PendingContinuationQueue())
			releaseLock()
		case .locked(var pending):
			// we are guaranteed a synchronous path from here to the
			// point the closure is executed and we need to hold our lock
			// that whole time. However, that `await` makes it
			// impossible to use the Mutex type.

			await withCheckedContinuation { continuation in
				pending.add(continuation)
				self.state = .locked(pending)

				releaseLock()
			}
		}
	}

	private func openGate() {
		lock.withLock {
			guard var pending = state.pending else {
				preconditionFailure("Gate is not closed")
			}

			if pending.isEmpty {
				self.state = .unlocked
				return
			}

			pending.resumeNext()

			self.state = .locked(pending)
		}
	}

	public var isGated: Bool {
		get {
			lock.withLock { state.pending != nil }
		}
	}

	public func escalatePriority(to priority: TaskPriority) {
		lock.withLock {
			state.pending?.escalatePriority(to: priority)
		}
	}

	public func withGate<Result, Failure>(
		_ body: () async throws(Failure) -> Result
	) async throws(Failure) -> Result where Failure: Error {
		try await withEscalationMonitoring { () throws(Failure) -> Result in
			await closeGate()

			do throws(Failure) {
				let value = try await body()

				openGate()

				return value
			} catch {
				openGate()

				// unsure why the compiler believes this could be `any Error`
				throw error
			}
		}
	}

	private func withEscalationMonitoring<Result, Failure: Error>(
		_ body: () async throws(Failure) -> Result
	) async throws(Failure) -> Result {
		guard #available(macOS 26.0, macCatalyst 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *) else {
			return try await body()
		}

		// we are using locks exclusively so that Task can capture self here,
		// but we do not want to make the type visibly Sendable.
		nonisolated(unsafe) let uncheckedSelf = self

		return try await withTaskPriorityEscalationHandler { () throws(Failure) -> Result in
			try await body()
		} onPriorityEscalated: { _, newPriority in
			Task {
				uncheckedSelf.escalatePriority(to: newPriority)
			}
		}
	}
}
