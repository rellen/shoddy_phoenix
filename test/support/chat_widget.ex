defmodule ShoddyPhoenix.Test.ChatWidget do
  @moduledoc false
  # This widget is the example of the how-to guide "Build a widget with
  # lifecycle hooks". Only the name of the module and the PubSub server are
  # different.
  use Phoenix.Component
  use ShoddyPhoenix.LiveView.Events, prefix: "chat"

  alias ShoddyPhoenix.LiveView
  alias ShoddyPhoenix.LiveView.Subscriptions
  alias ShoddyPhoenix.LiveView.Widgets
  alias ShoddyPhoenix.Test.PubSub

  @pubsub PubSub

  defstruct [:key, :topic, messages: []]

  def assign_widget(socket, key, topic) do
    socket
    |> assign(key, %__MODULE__{key: key, topic: topic})
    |> Subscriptions.subscribe(@pubsub, topic, key)
    |> Widgets.route_events(event_prefix(), &handle_event/3)
    |> LiveView.put_hook({__MODULE__, :info}, :handle_info, &handle_info/2)
  end

  def remove_widget(socket, key) do
    %__MODULE__{topic: topic} = socket.assigns[key]

    socket
    |> Subscriptions.unsubscribe(@pubsub, topic, key)
    |> assign(key, nil)
  end

  attr :state, __MODULE__, required: true

  def render(assigns) do
    ~H"""
    <section id={"chat-#{@state.key}"}>
      <ul>
        <li :for={message <- @state.messages}>{message}</li>
      </ul>
      <form phx-submit={event("send")}>
        <input type="hidden" name="instance" value={@state.key} />
        <label>Message <input type="text" name="message" /></label>
        <button>Send</button>
      </form>
    </section>
    """
  end

  defp handle_event("send", %{"instance" => instance, "message" => message}, socket) when is_binary(message) do
    with {:ok, {_key, state}} <- Widgets.fetch_instance(socket, __MODULE__, instance),
         message when message != "" <- String.trim(message) do
      Phoenix.PubSub.broadcast(@pubsub, state.topic, {__MODULE__, state.topic, message})
    end

    {:noreply, socket}
  end

  defp handle_event("send", _params, socket), do: {:noreply, socket}

  defp handle_info({__MODULE__, topic, message}, socket) do
    socket =
      for {key, %__MODULE__{topic: ^topic} = state} <- socket.assigns, reduce: socket do
        socket -> assign(socket, key, %{state | messages: state.messages ++ [message]})
      end

    {:halt, socket}
  end

  defp handle_info(_message, socket), do: {:cont, socket}
end
