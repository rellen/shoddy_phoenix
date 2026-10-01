# This module needs Phoenix.LiveView, which is part of the optional dependency
# phoenix_live_view. Without that dependency, this file defines no module.
if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule ShoddyPhoenix.LiveView.Subscriptions do
    @moduledoc """
    Functions that subscribe a LiveView to PubSub topics for each part that
    needs a topic.

    - `subscribe/4` records an owner of a topic. The first owner subscribes
      the process of the LiveView to the topic.
    - `unsubscribe/4` removes an owner of a topic. When no owner remains, the
      process unsubscribes from the topic.

    An owner is a term that names one part of the LiveView, such as the key of
    a widget. Each function returns the socket:

    ```elixir
    socket
    |> Subscriptions.subscribe(MyApp.PubSub, "chat:lobby", :left_chat)
    |> Subscriptions.subscribe(MyApp.PubSub, "chat:lobby", :right_chat)
    ```

    The process has one subscription to `"chat:lobby"`, so it receives each
    message of that topic one time. Give the message to each part in
    `handle_info/2`, or in a `:handle_info` hook.

    ## Why owners

    A LiveView can have several parts that need the same topic, such as two
    widgets. Phoenix.PubSub has two rules that make this difficult:

    - Each call of `Phoenix.PubSub.subscribe/2` adds a subscription. A process
      with two subscriptions to a topic receives each message two times.
    - `Phoenix.PubSub.unsubscribe/2` removes each subscription of the process
      to the topic. When one part unsubscribes, the other parts also receive no
      more messages.

    The record of owners prevents both problems. A second `subscribe/4` adds
    an owner but no subscription. An `unsubscribe/4` removes the subscription
    only with the last owner. A repeated call with the same owner changes
    nothing.

    ## Only a connected socket

    Both functions do nothing for a socket that is not connected. The
    disconnected render runs in the process of the HTTP request, and that
    process must not subscribe. Call `subscribe/4` in `mount/3`. The
    connected mount then subscribes. The section "The two renders" of
    `ShoddyPhoenix.LiveView` tells more.

    ## Use this module for each subscription to a topic

    The record is in the socket. It does not know about other calls of
    `Phoenix.PubSub.subscribe/2` or `Phoenix.PubSub.unsubscribe/2` in the same
    LiveView:

    - If other code also subscribes to the topic, the process receives each
      message two times.
    - If other code unsubscribes from the topic, it also removes the
      subscription of this module.

    ## A LiveComponent

    A LiveComponent runs in the process of its LiveView, and LiveView sends
    each message to the LiveView, not to the component. A LiveComponent also
    has its own socket, so it cannot change the record of its LiveView. Thus
    both functions raise `ArgumentError` for the socket of a LiveComponent.

    ## Usage

    This module exists only if your project has the dependency
    `phoenix_live_view`, version 1.2 or a later version before 2.0.
    """

    alias Phoenix.LiveComponent.CID
    alias Phoenix.LiveView.Socket
    alias ShoddyPhoenix.LiveView

    # The record of owners is in the private data of the socket, under this
    # key. The documentation of Phoenix.LiveView.put_private/3 asks a library
    # to put its name at the start of the key.
    @private_key :shoddy_phoenix_subscriptions

    @doc """
    Records `owner` as an owner of `topic`, and subscribes the LiveView to
    `topic` for the first owner.

    `pubsub` is the name of the PubSub server, such as `MyApp.PubSub`. `owner`
    can be each term. For a socket that is not connected, `subscribe/4`
    returns the socket and does nothing.

        socket
        |> Subscriptions.subscribe(MyApp.PubSub, "chat:lobby", :left_chat)

    A second call with the same `owner` changes nothing. A call with another
    owner adds that owner, but it does not subscribe the process again.

    `subscribe/4` raises `ArgumentError` for the socket of a LiveComponent. It
    raises `FunctionClauseError` for an argument of the wrong type, such as a
    `topic` that is not a string.
    """
    @spec subscribe(Socket.t(), atom(), String.t(), term()) :: Socket.t()
    def subscribe(%Socket{} = socket, pubsub, topic, owner) when is_atom(pubsub) and is_binary(topic) do
      socket
      |> ensure_live_view!(:subscribe)
      |> LiveView.when_connected(fn socket ->
        owners = owners(socket, pubsub, topic)

        if MapSet.size(owners) == 0 do
          :ok = Phoenix.PubSub.subscribe(pubsub, topic)
        end

        put_owners(socket, pubsub, topic, MapSet.put(owners, owner))
      end)
    end

    @doc """
    Removes `owner` as an owner of `topic`, and unsubscribes the LiveView from
    `topic` when no owner remains.

    For a socket that is not connected, `unsubscribe/4` returns the socket and
    does nothing. For an `owner` that is not an owner of `topic`, it also does
    nothing.

        socket
        |> Subscriptions.unsubscribe(MyApp.PubSub, "chat:lobby", :left_chat)

    `unsubscribe/4` raises the same errors as `subscribe/4`.
    """
    @spec unsubscribe(Socket.t(), atom(), String.t(), term()) :: Socket.t()
    def unsubscribe(%Socket{} = socket, pubsub, topic, owner) when is_atom(pubsub) and is_binary(topic) do
      socket
      |> ensure_live_view!(:unsubscribe)
      |> LiveView.when_connected(fn socket ->
        owners = owners(socket, pubsub, topic)
        remaining = MapSet.delete(owners, owner)

        if MapSet.member?(owners, owner) and MapSet.size(remaining) == 0 do
          :ok = Phoenix.PubSub.unsubscribe(pubsub, topic)
        end

        put_owners(socket, pubsub, topic, remaining)
      end)
    end

    defp ensure_live_view!(%Socket{assigns: %{myself: %CID{}}}, function) do
      raise ArgumentError,
            "ShoddyPhoenix.LiveView.Subscriptions.#{function}/4 does not accept the socket of a " <>
              "LiveComponent. LiveView sends each message to the LiveView, so subscribe in the LiveView."
    end

    defp ensure_live_view!(socket, _function), do: socket

    defp owners(socket, pubsub, topic) do
      socket.private
      |> Map.get(@private_key, %{})
      |> Map.get({pubsub, topic}, MapSet.new())
    end

    defp put_owners(socket, pubsub, topic, owners) do
      record = Map.get(socket.private, @private_key, %{})

      record =
        if MapSet.size(owners) == 0,
          do: Map.delete(record, {pubsub, topic}),
          else: Map.put(record, {pubsub, topic}, owners)

      Phoenix.LiveView.put_private(socket, @private_key, record)
    end
  end
end
