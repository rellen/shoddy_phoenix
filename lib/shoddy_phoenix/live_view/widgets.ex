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

    - `route_events/4` sends each event that starts with the name of a widget
      and a colon to a function of the widget.
    - `route_instance_events/5` does the same, and it also gives the function
      the instance that the event names.
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

    A client can send an event with each action. Give the list of the actions
    of the widget with the option `:actions`. Then the hook halts each other
    action, and the handler needs no clause for it.

    ## The name of a widget

    A name is a string that is not empty and that contains no colon. The
    colon separates the name from the rest of the event name. Thus the name
    `"chat"` never owns the event `"chatter:send"`.

    One name belongs to one module, which is the module that defines the
    handler. `route_events/4` and `route_instance_events/5` raise
    `ArgumentError` when a handler of another module asks for a name that is
    in use. When the same module asks for its name again, for example for a
    second instance, the function replaces its hook.

    ## The instance of an event

    A client chooses the parameters of each event, and it can send each
    value. Do not convert a parameter into an atom with
    `String.to_existing_atom/1`. That function raises for an unknown string,
    and the atom can name an assign of another kind.

    `fetch_instance/3` compares the parameter with the keys of the assigns
    that contain a struct of the widget. It returns `:error` for each other
    value, also for `nil`. Thus a wrong parameter cannot crash the LiveView,
    and it cannot select another assign.

    `route_instance_events/5` calls `fetch_instance/3` for each event, and it
    halts an event that names no instance.
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

    @typedoc """
    A function that handles the events of a widget.

    It gets the action, the parameters of the event and the socket. It
    returns `{:noreply, socket}` or `{:reply, map, socket}`, as
    `handle_event/3` does.
    """
    @type handler() ::
            (String.t(), map(), Socket.t() -> {:noreply, Socket.t()} | {:reply, map(), Socket.t()})

    @typedoc """
    A function that handles the events of a widget, with the instance that
    the event names.

    It gets the action, the parameters of the event, the key and the struct
    of the instance, and the socket. It returns the same values as a
    `t:handler/0`.
    """
    @type instance_handler() ::
            (String.t(), map(), {atom(), struct()}, Socket.t() ->
               {:noreply, Socket.t()} | {:reply, map(), Socket.t()})

    @doc """
    Sends each event that starts with `name` and a colon to `handler`.

    `route_events/4` attaches a `:handle_event` hook. For the event
    `"chat:send"` and the name `"chat"`, the hook calls
    `handler.("send", params, socket)`. The handler must return
    `{:noreply, socket}` or `{:reply, map, socket}`. Otherwise the hook raises
    `ArgumentError`. The hook halts each event of the widget, so the
    LiveView never receives it. Other events go to the LiveView.

        socket
        |> Widgets.route_events("chat", &handle_event/3)

    ## Options

    - `:actions` is the list of the actions that the handler handles. The
      hook halts an event with another action, and it does not call the
      handler. Without this option, the hook calls the handler for each
      action.

    ```elixir
    socket
    |> Widgets.route_events("chat", &handle_event/3, actions: ["send", "clear"])
    ```

    A client can send an event with each name. Without `:actions`, the
    handler raises `FunctionClauseError` for an action with no clause, and
    the LiveView crashes. A last clause that accepts each action prevents
    the crash, but it stops the check of `ShoddyPhoenix.LiveView.Events`.
    The option `:actions` prevents the crash, and the check stays on.

    ## Errors

    `route_events/4` raises `ArgumentError` for an empty name, for a name
    with a colon, or for a name that a handler of another module uses. A
    second call from the module that uses the name replaces its hook. It
    also raises `ArgumentError` for an unknown option, and for `:actions`
    that is not a list of strings with at least one string.

    It raises `FunctionClauseError` for an argument of the wrong type, such
    as a handler of an arity other than 3 or options that are not a list.
    """
    @spec route_events(Socket.t(), String.t(), handler(), keyword()) :: Socket.t()
    def route_events(%Socket{} = socket, name, handler, opts \\ [])
        when is_binary(name) and is_function(handler, 3) and is_list(opts) do
      opts = Keyword.validate!(opts, [:actions])

      attach(socket, name, handler, actions!(opts), fn action, params, socket ->
        {:call, handler.(action, params, socket)}
      end)
    end

    @doc """
    Sends each event of a widget to `handler`, with the instance that the
    event names.

    `route_instance_events/5` is `route_events/4` with a call of
    `fetch_instance/3` in front of the handler. For the event `"chat:send"`,
    the hook reads the parameter `"instance"` of the event. It finds the
    `module` struct in the assign that the parameter names. Then it calls
    `handler.("send", params, {key, instance}, socket)`.

        socket
        |> Widgets.route_instance_events("chat", __MODULE__, &handle_event/4)

        defp handle_event("send", %{"message" => message}, {_key, state}, socket) do
          ...
        end

    The hook halts an event with no instance parameter, or with a parameter
    that names no instance. It does not call the handler for such an event.
    Thus the handler needs no code for an event without an instance. A
    client can send such an event, for example from a page that shows an
    instance that the LiveView removed.

    The handler gets the key of the assign with the struct. Give that key to
    `Phoenix.Component.assign/3` to put a changed struct into the socket.

    ## Options

    - `:param` is the name of the parameter that names the instance. The
      default is `"instance"`.
    - `:actions` is the list of the actions that the handler handles, as in
      `route_events/4`. The hook halts an event with another action before
      it reads the parameter.

    ## Errors

    `route_instance_events/5` raises `ArgumentError` for the same names and
    options as `route_events/4`, and for a `:param` that is not a string.
    It raises `FunctionClauseError` for an argument of the wrong type, such
    as a `module` that is not an atom or a handler of an arity other than 4.
    """
    @spec route_instance_events(Socket.t(), String.t(), module(), instance_handler(), keyword()) :: Socket.t()
    def route_instance_events(%Socket{} = socket, name, module, handler, opts \\ [])
        when is_binary(name) and is_atom(module) and is_function(handler, 4) and is_list(opts) do
      opts = Keyword.validate!(opts, [:actions, param: "instance"])
      param = param!(opts)

      attach(socket, name, handler, actions!(opts), fn action, params, socket ->
        case fetch_instance(socket, module, Map.get(params, param)) do
          {:ok, instance} -> {:call, handler.(action, params, instance, socket)}
          :error -> :ignore
        end
      end)
    end

    @doc """
    Stops `route_events/4` or `route_instance_events/5` for `name`.

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

    # Puts the name of the widget into the private data of the socket, and
    # attaches the hook. The function dispatch calls the handler, and it
    # returns {:call, result}, or :ignore when the event has no instance.
    defp attach(socket, name, handler, actions, dispatch) do
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
            route(event, params, socket, name, prefix, actions, dispatch)
          end)
      end
    end

    defp route(event, params, socket, name, prefix, actions, dispatch) do
      case event do
        ^prefix <> action ->
          if actions == nil or action in actions do
            reply(dispatch.(action, params, socket), name, socket)
          else
            {:halt, socket}
          end

        _other_event ->
          {:cont, socket}
      end
    end

    defp reply(:ignore, _name, socket), do: {:halt, socket}
    defp reply({:call, {:noreply, %Socket{} = socket}}, _name, _socket), do: {:halt, socket}

    defp reply({:call, {:reply, reply, %Socket{} = socket}}, _name, _socket) when is_map(reply),
      do: {:halt, reply, socket}

    defp reply({:call, other}, name, _socket) do
      raise ArgumentError,
            "the event handler of the widget #{inspect(name)} must return " <>
              "{:noreply, socket} or {:reply, map, socket}. It returned #{inspect(other)}."
    end

    defp actions!(opts) do
      case opts[:actions] do
        nil ->
          nil

        [_first | _rest] = actions ->
          if Enum.all?(actions, &is_binary/1), do: actions, else: invalid_actions!(actions)

        other ->
          invalid_actions!(other)
      end
    end

    defp invalid_actions!(actions) do
      raise ArgumentError,
            "the option :actions must be a list of strings with at least one string. " <>
              "It was #{inspect(actions)}."
    end

    defp param!(opts) do
      case opts[:param] do
        param when is_binary(param) ->
          param

        other ->
          raise ArgumentError, "the option :param must be a string. It was #{inspect(other)}."
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
