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
- Add `ShoddyPhoenix.LiveView.when_connected/2` and
  `ShoddyPhoenix.LiveView.when_not_connected/2`. These functions apply a
  function to the socket of a LiveView only when the socket is connected,
  or only when it is not connected. The module needs the optional dependency
  `phoenix_live_view`.
- Add `ShoddyPhoenix.LiveView.put_hook/4`, which attaches a lifecycle hook
  and replaces a hook with the same id and stage.
- Add `ShoddyPhoenix.LiveView.Subscriptions`, which subscribes a LiveView to
  a PubSub topic for each owner. The LiveView has one subscription for each
  topic, and it unsubscribes when the last owner unsubscribes.
- Add `ShoddyPhoenix.LiveView.Widgets`, which sends the events of a widget to
  a function of the widget, and which finds the instance that an event names.
- Add `ShoddyPhoenix.LiveView.Events`. Its macro `event/1` returns the name
  of an event, and the compiler then warns about a name with no clause of
  `handle_event/3`. Its option `:prefix` and its macro `event_prefix/0` are for
  the events of a widget.
