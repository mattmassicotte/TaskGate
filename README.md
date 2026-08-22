<div align="center">

[![Build Status][build status badge]][build status]
[![Platforms][platforms badge]][platforms]

</div>

# TaskGate
An tool for managing actor reentrancy.

This package exposes two types: `AsyncGate` and `AsyncRecursiveGate`. These allow you to define **asynchronous** critical sections. Only one task can enter a critical section at a time. Unlike a traditional lock, you can safely make async calls while these gates are held.

The intended use-case for these is managing actor reentrancy.

Despite being similar conceptually, it's worth noting that this type is not called a "lock". Gates do not block the current **thread**. They operate at the task level and this is different enough that a new name seemed appropriate.

Some other concurrency packages you might find useful are [Queue][] and [Semaphore][]. [Gate][] is an independent, but extremely similar package.

## Integration

Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/dimasusername/TaskGate", branch: "main")
]
```

## Usage

Gates are very intentionally **non-Sendable**. The purpose of a gate is to control tasks running concurrently within a **single** actor, and making them non-`Sendable` allows the compiler to help enforce this.

Note that trying to acquire an already-gated `AsyncGate` **will** deadlock your actor.

```swift
import TaskGate

actor MyActor {
  var value = 42
  let gate = AsyncGate()
  let recursiveGate = AsyncRecursiveGate()

  func hasCriticalSections() async {
    // no matter how many tasks call this method,
    // only one will be able to execute at a time
    await gate.withGate {
      await work()
      self.value = await otherObject.getValue()
    }
  }

  func hasNestedCriticalSections() async {
    await recursiveGate.withGate {
      // acquiring this multiple times within the same task is safe
      await recursiveGate.withGate {
        await work()
        self.value = await otherObject.getValue()
      }
    }
  }
}
```

Both of these gate types support priority escalation propagation to help avoid priority inversions. However, the API required to do this was introduced with [SE-0462](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0462-task-priority-escalation-apis.md), which is only available in the 26 OSes and later.

It is important to note that gates cannot be used from a non-async context. Actually doing this would require some trickery, as they both only have async interfaces. But, if you find a way, perhaps via ObjC bridging, you should expect a crash.

## Contributing and Collaboration

I would love to hear from you! Issues or pull requests work great.

I prefer collaboration, and would love to find ways to work together if you have a similar project.

I prefer indentation with tabs for improved accessibility. But, I'd rather you use the system you want and make a PR than hesitate because of whitespace.

By participating in this project you agree to abide by the [Contributor Code of Conduct](CODE_OF_CONDUCT.md).

[build status]: https://github.com/dimasusername/TaskGate/actions
[build status badge]: https://github.com/dimasusername/TaskGate/workflows/CI/badge.svg
[platforms]: https://swiftpackageindex.com/dimasusername/TaskGate
[platforms badge]: https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fdimasusername%2FTaskGate%2Fbadge%3Ftype%3Dplatforms
[Semaphore]: https://github.com/groue/Semaphore
[Queue]: https://github.com/dimasusername/Queue
[Gate]: https://github.com/wadetregaskis/Gate
