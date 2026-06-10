# Test Style

Tests should explain the behavior they protect, not just the implementation detail they touch.

Use this shape for new tests when it makes the intent clearer:

```swift
func testUserVisibleScenarioDoesExpectedThing() async throws {
    // Given the relevant app or API state.
    ...

    // When the user action or service call happens.
    ...

    // Then the observable result matches the product expectation.
    XCTAssertEqual(actual, expected, "Explain why this value matters when the failure would be cryptic.")
}
```

Prefer:

- Test names that describe the scenario and expected outcome.
- `Given`, `When`, `Then` comments for multi-step tests.
- Assertion messages for network requests, fallback behavior, and user-visible state.
- Fixture names and sample values that match the real bug or workflow being protected.

Avoid:

- Names that only repeat the method under test.
- Large anonymous JSON payloads without a nearby comment explaining the case.
- Assertions that prove an internal call happened without also checking the user-visible result.
