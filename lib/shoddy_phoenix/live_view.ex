# This module needs Phoenix.LiveView, which is part of the optional dependency
# phoenix_live_view. Without that dependency, this file defines no module.
if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule ShoddyPhoenix.LiveView do
    @moduledoc """
    Functions that operate on the socket of a LiveView.

    - `when_connected/2` applies a function to the socket only when the socket
      is connected.
    - `when_not_connected/2` applies a function to the socket only when the
      socket is not connected.

    Each function returns a socket, so it can be a step of a pipeline:

    ```elixir
    def mount(_params, _session, socket) do
      socket =
        socket
        |> assign(:messages, [])
        |> LiveView.when_connected(&subscribe/1)

      {:ok, socket}
    end

    defp subscribe(socket) do
      Phoenix.PubSub.subscribe(MyApp.PubSub, "messages")
      socket
    end
    ```

    Read [the two renders](#module-the-two-renders) before you use these
    functions. A LiveView can mount two times, and the second mount does not
    get the assigns of the first mount.

    ## Usage

    This module exists only if your project has the dependency
    `phoenix_live_view`, version 1.2 or a later version before 2.0.

    Alias the module in each LiveView that uses it:

    ```elixir
    alias ShoddyPhoenix.LiveView
    ```

    The alias changes only a name that starts with `LiveView`. A name such as
    `Phoenix.LiveView.JS` does not change. If the module already has the alias
    `LiveView` for `Phoenix.LiveView`, give this module another alias:

    ```elixir
    alias ShoddyPhoenix.LiveView, as: ShoddyLiveView
    ```

    ## The two renders

    When a browser requests the page of a LiveView over HTTP, two renders
    occur:

    1. LiveView calls `mount/3` with a socket that is not connected. It
       renders the HTML, and it sends that HTML in the HTTP response. This
       render is the disconnected render. It runs in the process of the HTTP
       request.
    2. The browser connects to the server. LiveView starts the process of the
       LiveView, and it calls `mount/3` again with a connected socket. This
       render is the connected render.

    LiveView calls each `on_mount` hook and `handle_params/3` in both renders.
    A LiveComponent has the connection state of its LiveView.

    These rules have three consequences:

    - The connected process does not get the assigns of the disconnected
      render. If `when_not_connected/2` assigns a value, the connected mount
      must also assign it. Otherwise the connected render raises `KeyError`.
    - A live navigation causes no disconnected render. For example, a click
      on `<.link navigate={...}>` to a LiveView in the same `live_session`
      mounts that LiveView with a connected socket only. Then
      `when_not_connected/2` does not call its function.
    - LiveView calls `handle_event/3` and `handle_info/2` only in the
      connected process. In these callbacks, `when_connected/2` always calls
      its function, and `when_not_connected/2` never calls it.

    ## The function must return a socket

    Each function of this module calls its function with the socket, and it
    returns the result in place of the socket. Thus that result must be a
    socket.

    A function that ends with a call such as `Phoenix.PubSub.subscribe/2`
    returns the result of that call, which is `:ok`. Each function of this
    module raises `ArgumentError` for a result that is not a socket. Thus the
    error occurs in the call that has the mistake.

    ## When to use something else

    - `Phoenix.LiveView.assign_async/4` and `Phoenix.LiveView.start_async/4`
      start their task only when the socket is connected. They need no
      `when_connected/2`.
    - A `mount/3` without a pipeline can call `Phoenix.LiveView.connected?/1`
      directly, as in `if connected?(socket), do: subscribe()`. In that form,
      `subscribe/0` does not need to return the socket.
    """

    alias Phoenix.LiveView.Socket

    @doc """
    Applies a function to the socket only when the socket is connected.

    If the socket is connected, `when_connected/2` calls `fun` with the
    socket, and it returns the result. Otherwise it returns the socket, and
    it does not call `fun`.

    `fun` must return a socket. Otherwise `when_connected/2` raises
    `ArgumentError`. It raises `FunctionClauseError` for a first argument that
    is not a socket, or for a function of an arity other than 1.

    Use this function for work that must occur in the process of the
    LiveView, such as a subscription to a PubSub topic or a timer:

        socket
        |> assign(:messages, [])
        |> LiveView.when_connected(fn socket ->
          Phoenix.PubSub.subscribe(MyApp.PubSub, "messages")
          socket
        end)

    In `mount/3`, the function runs only in the connected render.
    [The two renders](#module-the-two-renders) tells when each render occurs.
    """
    @spec when_connected(Socket.t(), (Socket.t() -> Socket.t())) :: Socket.t()
    def when_connected(%Socket{} = socket, fun) when is_function(fun, 1) do
      if Phoenix.LiveView.connected?(socket), do: apply_to(socket, fun, :when_connected), else: socket
    end

    @doc """
    Applies a function to the socket only when the socket is not connected.

    If the socket is not connected, `when_not_connected/2` calls `fun` with
    the socket, and it returns the result. Otherwise it returns the socket,
    and it does not call `fun`.

    `fun` must return a socket. Otherwise `when_not_connected/2` raises
    `ArgumentError`. It raises `FunctionClauseError` for a first argument that
    is not a socket, or for a function of an arity other than 1.

    > #### The function does not always run {: .warning}
    >
    > A live navigation mounts a LiveView with a connected socket only. Then
    > `when_not_connected/2` does not call its function. Also, the connected
    > process does not get the assigns that the function sets.
    > [The two renders](#module-the-two-renders) tells more.

    Use this function to change only the HTML of the HTTP response. For
    example, show a placeholder in that response, and load the data after the
    connection:

        socket
        |> LiveView.when_not_connected(fn socket -> render_with(socket, &loading/1) end)
        |> LiveView.when_connected(&assign(&1, :rows, Reports.list_rows()))

    The connected render uses the template of the LiveView, so only that
    render needs `@rows`. `Phoenix.LiveView.render_with/2` tells more.
    """
    @spec when_not_connected(Socket.t(), (Socket.t() -> Socket.t())) :: Socket.t()
    def when_not_connected(%Socket{} = socket, fun) when is_function(fun, 1) do
      if Phoenix.LiveView.connected?(socket), do: socket, else: apply_to(socket, fun, :when_not_connected)
    end

    defp apply_to(socket, fun, name) do
      case fun.(socket) do
        %Socket{} = result ->
          result

        other ->
          raise ArgumentError,
                "ShoddyPhoenix.LiveView.#{name}/2 needs a function that returns a socket. " <>
                  "The function returned #{inspect(other)}. A call such as " <>
                  "Phoenix.PubSub.subscribe/2 returns :ok, so return the socket after that call."
      end
    end
  end
end
