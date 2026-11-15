# Usage rules for ShoddyPhoenix

ShoddyPhoenix is a library of small components and functions for Phoenix
LiveView. These rules tell an AI agent how to use the library correctly.
The documentation of each module gives the full description.

## General rules

- Each module needs `phoenix_live_view`, version 1.2 or a later version
  before 2.0. Without that dependency, the modules do not exist.
- ShoddyPhoenix does not add Shoddy to a project. Call a function of
  `Shoddy` only if `mix.exs` has the dependency `shoddy`. Shoddy has its
  own usage rules.
- Import `ShoddyPhoenix.ControlFlow` in the function `html_helpers/0` of
  `lib/my_app_web.ex`. If the application has a component with the same
  name, such as a `switch/1`, import with the option `:only`.
- Only `nil` and `false` are falsy. Zero, `""` and `[]` are truthy.

## Components

- A component of `ShoddyPhoenix.ControlFlow` adds no element. Write the
  list element or the table element around the component.
- `ShoddyPhoenix.ControlFlow.choose/1` evaluates the `test` of each
  `<:when>` on each render, also after a truthy test. Do not write a test
  that is safe only after an earlier test. For a user that can be `nil`,
  write `test={@user && @user.admin?}`.
- `ShoddyPhoenix.ControlFlow.switch/1` compares with `===/2`. Thus `1` and
  `1.0` are two different values.
- `ShoddyPhoenix.ControlFlow.result/1` raises `FunctionClauseError` for a
  value that is not a result, such as `nil`. For an assign that can be
  `nil`, write `:if={@save}` on the component.
- Do not render the reason of `result/1` if it is a tuple, a map or a
  struct. Render a message or a field of the reason.
- The `<:wrapper>` of `ShoddyPhoenix.ControlFlow.wrap_if/1` must call
  `render_slot/1` with its `:let` argument. If it does not, the content
  disappears, and no error occurs.
- `ShoddyPhoenix.ControlFlow.each/1` raises `ArgumentError` for a LiveView
  stream. It also cannot take `:key`. For a long list that changes before
  its end, use `:for` with `:key`.

## Sockets

- A page request mounts a LiveView two times, and only the second socket is
  connected. `ShoddyPhoenix.LiveView.when_connected/2` applies a function
  only to a connected socket.
- The function of `when_connected/2` must return the socket.
  `Phoenix.PubSub.subscribe/2` returns `:ok`, so return the socket after
  that call.
- Subscribe first. Then read the state that the topic changes, and assign
  it. The other order loses each change between the read and the
  subscription.
- Do not put an assign that the template needs into the function of
  `when_connected/2`. The first mount does not call the function, and its
  render raises `KeyError`.
- Do not put `assign_async/4` or `start_async/4` into `when_connected/2`.
  They start their task only for a connected socket.
- `ShoddyPhoenix.LiveView.when_not_connected/2` is only for the HTML of the
  HTTP response. The second mount does not get its assigns.
- `ShoddyPhoenix.LiveView.put_hook/4` replaces a hook with the same id and
  stage. Use it in code that can run two times, where
  `Phoenix.LiveView.attach_hook/4` raises.
- If more than one part of a LiveView needs one topic, use
  `ShoddyPhoenix.LiveView.Subscriptions.subscribe/4` and
  `ShoddyPhoenix.LiveView.Subscriptions.unsubscribe/4`. Do not also call
  `Phoenix.PubSub.subscribe/2` for that topic.
- The functions of `ShoddyPhoenix.LiveView.Subscriptions` do nothing for a
  socket that is not connected. They raise `ArgumentError` for the socket
  of a LiveComponent.

## Widgets and event names

- `ShoddyPhoenix.LiveView.Widgets.route_events/4` removes the name of the
  widget and the colon from the event. For the name `"chat"` and the event
  `"chat:send"`, the handler gets `"send"`.
- Give the option `:actions` with the actions of the widget. Do not give
  the handler a last clause that accepts each action. A client can send
  each action, and such a clause stops the check of the event names.
- For a widget with instances, use
  `ShoddyPhoenix.LiveView.Widgets.route_instance_events/5`. The handler has
  four arguments, and the third argument is `{key, struct}`.
- Do not change a parameter of an event into an atom with
  `String.to_existing_atom/1`. Use
  `ShoddyPhoenix.LiveView.Widgets.fetch_instance/3`.
- After `use ShoddyPhoenix.LiveView.Events`, write each event name of a
  template with `ShoddyPhoenix.LiveView.Events.event/1`. The check does not
  see a plain string, such as `phx-click="save"`.
- `event/1` accepts only a literal string.
- To remove a warning of the check, correct the name or add the clause. Do
  not add a clause of `handle_event/3` with a variable as its first
  argument. Such a clause stops the check for the module.
- In a LiveComponent, use `event/1` only for an event with
  `phx-target={@myself}`. Another event goes to the LiveView.
- The option `:prefix` must be a literal string, not a module attribute.
  Give `ShoddyPhoenix.LiveView.Events.event_prefix/0` to `route_events/4`.
