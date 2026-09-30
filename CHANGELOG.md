# Changelog

This file lists the changes to ShoddyPhoenix in each release. `CLAUDE.md`
gives the rules for versions and releases.

## Unreleased

ShoddyPhoenix has no release yet. The first release contains these changes:

- Add `ShoddyPhoenix.ControlFlow.choose/1`, a function component that
  renders the first `<:when>` slot with a truthy test. A test can be a
  function of arity 0, and the component calls it only when no earlier test
  is truthy. The module needs the optional dependency `phoenix_live_view`.
- Add `ShoddyPhoenix.ControlFlow.switch/1`, a function component that
  renders the first `<:case>` slot with a value that is equal to the value
  of the component.
- Add `ShoddyPhoenix.ControlFlow.result/1`, a function component that
  renders `<:ok>` or `<:error>` for a result.
- Add `ShoddyPhoenix.ControlFlow.wrap_if/1`, a function component that puts
  its content into a wrapper only when a test is truthy.
- Add `ShoddyPhoenix.ControlFlow.each/1`, a function component that renders
  its content for each item of a list, or an `<:empty>` slot for an empty
  list.
