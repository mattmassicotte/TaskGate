import Foundation

/// Allows exactly one task to execute within a critical section.
///
/// AsyncGate allow you to define asynchronous critical sections. Only one task can enter a critical section at a time. Unlike a traditional lock, you can safely make async calls while these gates are held.
public final class AsyncGate {
	private enum State: Equatable {
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
		guard state == .unlocked else {
			preconditionFailure("deinit called while gate is active")
		}
	}

	// These two functions exist because NSLock.lock/unlock are marked as unavailable from
	// async methods. But we are being very careful.
	private func takeLock() {
		lock.lock()
	}

	private func releaseLock() {
		lock.unlock()
	}

	private func closeGate() async {
		// the wrapped functions must be used because we are in an async context
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

	/// Defines a critical section protected by the gate.
	///
	/// - Warning: Attemping to recursively call `withGate` **will** deadlock the current actor.
	public func withGate<Result, Failure>(
		_ body: () async throws(Failure) -> Result
	) async throws(Failure) -> Result where Failure: Error {
		try await withEscalationMonitoring { () throws(Failure) -> Result in
			await closeGate()
			defer { openGate() }

			return try await body()
		}
	}

	private func withEscalationMonitoring<Success, Failure: Error>(
		_ body: () async throws(Failure) -> Success
	) async throws(Failure) -> Success {
		guard #available(macOS 26.0, macCatalyst 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *) else {
			return try await body()
		}

		// we are using locks exclusively so that Task can capture self here,
		// but we do not want to make the type visibly Sendable.
		nonisolated(unsafe) let uncheckedSelf = self

		return try await withTaskPriorityEscalationHandler { () throws(Failure) -> Success in
			try await body()
		} onPriorityEscalated: { _, newPriority in
			// This task was added to prevent self deadlock from happening
			// without it, deadlock could happen because `escalatePriority`
			// will try to have the lock which is already in use by the same thread
			Task {
				uncheckedSelf.escalatePriority(to: newPriority)
			}
		}
	}
}
