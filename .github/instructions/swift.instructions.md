---
applyTo: "**/*.swift"
---
Use Swift strict concurrency. Mark ownership and actor isolation explicitly. Avoid `@unchecked Sendable` unless documented by an ADR and protected by tests. Never block audio callbacks. Prefer value types for immutable domain models, typed errors, dependency injection, and protocol-based adapters. Add tests for cancellation, timeout, race, restart, and permission-denied paths.
