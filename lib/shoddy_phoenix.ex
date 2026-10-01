defmodule ShoddyPhoenix do
  @moduledoc """
  Small functions and components for tasks that occur frequently in Phoenix
  code.

  ShoddyPhoenix is the companion library of
  [Shoddy](https://github.com/rellen/shoddy). It contains the functions and
  the components that need Phoenix, and it obeys the conventions of Shoddy.

  ## The modules

  - `ShoddyPhoenix.ControlFlow` has function components for control flow in
    HEEx templates. It needs the optional dependency `phoenix_live_view`.
  - `ShoddyPhoenix.LiveView` has functions that operate on the socket of a
    LiveView. It needs the optional dependency `phoenix_live_view`.
  - `ShoddyPhoenix.LiveView.Subscriptions` subscribes a LiveView to a PubSub
    topic for each owner.
  - `ShoddyPhoenix.LiveView.Widgets` sends the events of a widget to the code
    of that widget.

  A module that operates on the socket of a LiveView is under
  `ShoddyPhoenix.LiveView`. A module for templates is at the top level.
  """
end
