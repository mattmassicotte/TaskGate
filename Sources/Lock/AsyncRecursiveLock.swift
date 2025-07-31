// This thing doesn't quite work yet...
final class AsyncRecursiveLock {
	@TaskLocal private static var locked = false
	@TaskLocal private static var lockedSet = Set<ObjectIdentifier>()

	private let internalLock = AsyncLock()

	public init() {
	}

	public func withLock<T: Sendable, E: Error>(
		isolation: isolated (any Actor)? = #isolation,
		_ block: () async throws(E) -> T
	) async throws(E) -> T {
		let id = ObjectIdentifier(self)
		var set = Self.lockedSet

		let (needsLock, _) = set.insert(id)

		print("state:", id, needsLock)

		if needsLock == false {
			return try await block()
		}

		return try await internalLock.withLock { () throws(E) -> T in
			do {
				return try await Self.$lockedSet.withValue(set) {
					try await block()
				}
			} catch {
				/* withValue from TaskLocal does not seem to properly throw typed errors (yet?).
				 * It does rethrows though, so the forced cast should be valid. */
				throw error as! E
			}
		}
	}

//	public func withLock<T: Sendable, E: Error>(
//			isolation: isolated (any Actor)? = #isolation,
//			_ block: () async throws(E) -> T
//		) async throws(E) -> T {
//			if Self.locked {
//				return try await block()
//			}
//
//			await internalLock.lock()
//
//			do {
//				let value = try await Self.$locked.withValue(true) {
//					try await block()
//				}
//
//				internalLock.unlock()
//
//				return value
//			} catch {
//				internalLock.unlock()
//
//				throw error as! E
//			}
//		}
}
