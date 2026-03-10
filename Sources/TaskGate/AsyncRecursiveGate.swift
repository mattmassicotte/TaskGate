struct TaskSpecificIdentifier: Hashable {
	private let taskId: Int
	private let objectId: ObjectIdentifier

	init?(object: some AnyObject) {
		let id = withUnsafeCurrentTask { $0?.hashValue }

		guard let id else { return nil }

		self.taskId = id
		self.objectId = ObjectIdentifier(object)
	}
}

/// A task gate that can be re-acquired when already held.
public final class AsyncRecursiveGate {
	@TaskLocal private static var gatedSet = Set<TaskSpecificIdentifier>()

	private let internalGate = AsyncGate()

	public init() {
	}

	public var isGated: Bool {
		internalGate.isGated
	}

	/// Acquire the gate.
	///
	/// - note: This function has some limitations that could potentially be lifted if `TaskLocal.withValue` gained the ability
	/// to send results and added suport for non-Copyable types.
	public func withGate<Success: Sendable, Failure>(
		_ body: () async throws(Failure) -> Success
	) async throws(Failure) -> Success where Failure: Error {
		var set = Self.gatedSet
		guard let id = TaskSpecificIdentifier(object: self) else {
			preconditionFailure("AsyncRecursiveGate can only be used within the context of a Task")
		}

		let (needsGate, _) = set.insert(id)

		if needsGate == false {
			return try await body()
		}

		return try await internalGate.withGate { () async throws(Failure) -> Success in
			do {
				return try await Self.$gatedSet.withValue(set) {
					try await body()
				}
			} catch {
				// withValue does not support typed-throws yet
				throw error as! Failure
			}
		}
	}
}
