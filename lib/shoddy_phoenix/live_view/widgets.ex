# This module needs Phoenix.LiveView, which is part of the optional dependency
# phoenix_live_view. Without that dependency, this file defines no module.
if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule ShoddyPhoenix.LiveView.Widgets do
    @moduledoc """
    Functions that send the events of a widget to the code of that widget.

    In this documentation, a widget is a part of a LiveView with its own
    state, events and messages. The widget keeps its state in an assign of the
    LiveView, and it handles its events with lifecycle hooks. A LiveView can
    contain several instances of one widget.
    Each instance has its own assign. The how-to guide "Build a widget with
    lifecycle hooks" shows a complete widget.

    - `route_events/3` sends each event that starts with the name of a widget
      and a colon to a function of the widget.
    - `unroute_events/2` stops that.
    - `fetch_instance/3` finds the instance that a parameter of an event names.
      It makes no atom, and it does not raise for a wrong parameter.

    ```elixir
    socket
    |> Widgets.route_events("chat", &handle_event/3)
    ```

    ```heex
    <button phx-click="chat:clear" phx-value-instance={@state.key}>Clear</button>
    ```

    ## The events of a widget

    After `route_events(socket, "chat", handler)`, the widget owns each event
    with a name that starts with `"chat:"`. For the event `"chat:clear"`, the
    hook calls `handler.("clear", params, socket)`. The handler returns
    `{:noreply, socket}` or `{:reply, map, socket}`, as `handle_event/3` does.

    The LiveView never receives an event that the widget owns. If the handler
    has no clause for an event, it raises `FunctionClauseError`, as a
    `handle_event/3` with no clause does. The error then names the widget, not
    the LiveView. Give the handler a clause for each event of the widget,
    also for an input that the widget rejects, such as an empty message.

    ## The name of a widget

    A name is a string that is not empty and that contains no colon. The
    colon separates the name from the rest of the event name. Thus the name
    `"chat"` never owns the event `"chatter:send"`.

    One name belongs to one module, which is the module that defines the
    handler. `route_events/3` raises `ArgumentError` when a handler of another
    module asks for a name that is in use. When the same module asks for its
    name again, for example for a second instance, `route_events/3` replaces
    its hook.

    ## The instance of an event

    A client chooses the parameters of each event, and it can send each
    value. Do not convert a parameter into an atom with
    `String.to_existing_atom/1`. That function raises for an unknown string,
    and the atom can name an assign of another kind.

    `fetch_instance/3` compares the parameter with the keys of the assigns
    that contain a struct of the widget. It returns `:error` for each other
    value, also for `nil`. Thus a wrong parameter cannot crash the LiveView,
    and it cannot select another assign.

    ## Usage

    This module exists only if your project has the dependency
    `phoenix_live_view`, version 1.2 or a later version before 2.0.
    """

    alias Phoenix.LiveView.Socket
    alias ShoddyPhoenix.LiveView

    # The names that are in use, and the module of each name, are in the
    # private data of the socket, under this key. The documentation of
    # Phoenix.LiveView.put_private/3 asks a library to put its name at the
    # start of the key.
    @private_key :shoddy_phoenix_widgets

    @doc """
    Sends each event that starts with `name` and a colon to `handler`.

    `route_events/3` attaches a `:handle_event` hook. For the event
    `"chat:send"` and the name `"chat"`, the hook calls
    `handler.("send", params, socket)`. The handler must return
    `{:noreply, socket}` or `{:reply, map, socket}`. Otherwise the hook raises
    `ArgumentError`. The hook halts each event of the widget, so the
    LiveView never receives it. Other events go to the LiveView.

        socket
        |> Widgets.route_events("chat", &handle_event/3)

    `route_events/3` raises `ArgumentError` for an empty name, for a name
    with a colon, or for a name that a handler of another module uses. A
    second call from the module that uses the name replaces its hook. It
    raises `FunctionClauseError` for an argument of the wrong type, such as a
    handler of an arity other than 3.
    """
    @spec route_events(
            Socket.t(),
            String.t(),
            (String.t(), map(), Socket.t() -> {:noreply, Socket.t()} | {:reply, map(), Socket.t()})
          ) :: Socket.t()
    def route_events(%Socket{} = socket, name, handler) when is_binary(name) and is_function(handler, 3) do
      validate_name!(name)
      {:module, module} = Function.info(handler, :module)
      names = Map.get(socket.private, @private_key, %{})

      case Map.fetch(names, name) do
        {:ok, owner} when owner != module ->
          raise ArgumentError,
                "the widget name #{inspect(name)} belongs to #{inspect(owner)}, " <>
                  "so a handler of #{inspect(module)} cannot use it. Give each widget its own name."

        _owner_or_error ->
          prefix = name <> ":"

          socket
          |> Phoenix.LiveView.put_private(@private_key, Map.put(names, name, module))
          |> LiveView.put_hook({__MODULE__, name}, :handle_event, fn event, params, socket ->
            route(event, params, socket, name, prefix, handler)
          end)
      end
    end

    @doc """
    Stops `route_events/3` for `name`.

    `unroute_events/2` removes the hook of `name`, and the name is free for
    another module. Each later event with that name goes to the LiveView. For
    a name that is not in use, `unroute_events/2` returns the socket and does
    nothing.

        socket
        |> Widgets.unroute_events("chat")

    `unroute_events/2` raises `FunctionClauseError` for a first argument that
    is not a socket, or for a name that is not a string.
    """
    @spec unroute_events(Socket.t(), String.t()) :: Socket.t()
    def unroute_events(%Socket{} = socket, name) when is_binary(name) do
      names = Map.get(socket.private, @private_key, %{})

      socket
      |> Phoenix.LiveView.put_private(@private_key, Map.delete(names, name))
      |> Phoenix.LiveView.detach_hook({__MODULE__, name}, :handle_event)
    end

    @doc """
    Finds the instance of `module` in the assign that `name` names.

    `name` is usually a parameter of an event, such as the value of
    `phx-value-instance`. `fetch_instance/3` compares `name` with the key of
    each assign that contains a `module` struct. It returns
    `{:ok, {key, struct}}` for a match, and `:error` for each other value.

        Widgets.fetch_instance(socket, MyAppWeb.ChatWidget, params["instance"])
        #=> {:ok, {:left_chat, %MyAppWeb.ChatWidget{}}}

    `fetch_instance/3` makes no atom. It returns `:error` for each of these
    values:

    - an unknown string
    - the key of an assign that does not contain a `module` struct
    - a value that is not a string, such as `nil`

    It raises `FunctionClauseError` for a first argument that is not a socket,
    or for a `module` that is not an atom.
    """
    @spec fetch_instance(Socket.t(), module(), term()) :: {:ok, {atom(), struct()}} | :error
    def fetch_instance(%Socket{assigns: assigns}, module, name) when is_atom(module) do
      Enum.find_value(assigns, :error, fn
        {key, %^module{} = instance} -> if Atom.to_string(key) === name, do: {:ok, {key, instance}}
        _other -> nil
      end)
    end

    defp route(event, params, socket, name, prefix, handler) do
      case event do
        <<^prefix::binary-size(byte_size(prefix)), action::binary>> ->
          case handler.(action, params, socket) do
            {:noreply, %Socket{} = socket} ->
              {:halt, socket}

            {:reply, reply, %Socket{} = socket} when is_map(reply) ->
              {:halt, reply, socket}

            other ->
              raise ArgumentError,
                    "the event handler of the widget #{inspect(name)} must return " <>
                      "{:noreply, socket} or {:reply, map, socket}. It returned #{inspect(other)}."
          end

        _other_event ->
          {:cont, socket}
      end
    end

    defp validate_name!(name) do
      if name == "" or String.contains?(name, ":") do
        raise ArgumentError,
              "a widget name must be a string that is not empty and that contains no colon. " <>
                "It was #{inspect(name)}."
      end
    end
  end
end
