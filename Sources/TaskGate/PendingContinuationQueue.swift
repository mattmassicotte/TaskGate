struct PendingContinuationQueue {
	typealias Continuation = CheckedContinuation<Void, Never>

	struct Pair {
		let continuation: Continuation
		let task: UnsafeCurrentTask

		static func == (lhs: PendingContinuationQueue.Pair, rhs: PendingContinuationQueue.Pair) -> Bool {
			lhs.task == rhs.task
		}

		func hash(into hasher: inout Hasher) {
			task.hash(into: &hasher)
		}
	}

	private var pending: [Pair] = []

	mutating func add(_ continuation: Continuation) {
		guard let task = withUnsafeCurrentTask(body: { $0 }) else {
			preconditionFailure("this API cannot be used outside of an asynchronous function")
		}

		let pair = Pair(continuation: continuation, task: task)

		pending.append(pair)
	}

	mutating func wait() async {
		await withCheckedContinuation { continuation in
			add(continuation)
		}
	}

	mutating func resumeNext() {
		if isEmpty {
			preconditionFailure("No continuations to resume")
		}

		let pair = pending.removeFirst()

		pair.continuation.resume()
	}

	func escalatePriority(to priority: TaskPriority) {
#if swift(>=6.2)
		// it is ok for this to be a no-op when empty or unavailable
		guard #available(macOS 26.0, macCatalyst 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0, *) else { return }

		for pair in pending {
			pair.task.escalatePriority(to: priority)
		}
#endif
	}

	var isEmpty: Bool { pending.isEmpty }
}
