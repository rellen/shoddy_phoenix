defmodule ShoddyPhoenix.Test.ReadFirstLive do
  @moduledoc false
  # This LiveView reads the messages, and then it subscribes. That is the
  # order that the documentation warns about. A change between the two steps
  # does not show on the page.
  use Phoenix.LiveView

  import Shoddy.Tagging, only: [noreply: 1, ok: 1]

  alias ShoddyPhoenix.LiveView
  alias ShoddyPhoenix.Test.Messages
  alias ShoddyPhoenix.Test.PubSub

  def mount(_params, _session, socket) do
    socket
    |> assign(:messages, Messages.list_recent())
    |> LiveView.when_connected(&subscribe/1)
    |> ok()
  end

  def handle_info({:new_message, message}, socket) do
    socket |> update(:messages, &[message | &1]) |> noreply()
  end

  defp subscribe(socket) do
    Phoenix.PubSub.subscribe(PubSub, "messages")
    socket
  end

  def render(assigns), do: ~H"<p :for={message <- @messages}>{message.text}</p>"
end

defmodule ShoddyPhoenix.Test.AppendLive do
  @moduledoc false
  # This LiveView subscribes, and then it reads the messages. But it adds each
  # message that it receives. A message of a change that the read already
  # contains then shows two times.
  use Phoenix.LiveView

  import Shoddy.Tagging, only: [noreply: 1, ok: 1]

  alias ShoddyPhoenix.LiveView
  alias ShoddyPhoenix.Test.Messages
  alias ShoddyPhoenix.Test.PubSub

  def mount(_params, _session, socket) do
    socket
    |> LiveView.when_connected(&subscribe/1)
    |> assign(:messages, Messages.list_recent())
    |> ok()
  end

  def handle_info({:new_message, message}, socket) do
    socket |> update(:messages, &[message | &1]) |> noreply()
  end

  defp subscribe(socket) do
    Phoenix.PubSub.subscribe(PubSub, "messages")
    socket
  end

  def render(assigns), do: ~H"<p :for={message <- @messages}>{message.text}</p>"
end
