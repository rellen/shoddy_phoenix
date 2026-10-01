defmodule ShoddyPhoenix.Test.GuideChatLive do
  @moduledoc false
  # This LiveView is the example of the how-to guide "Build a widget with
  # lifecycle hooks". Only the name of the module is different.
  use Phoenix.LiveView

  alias ShoddyPhoenix.Test.ChatWidget

  def mount(_params, _session, socket) do
    socket =
      socket
      |> ChatWidget.assign_widget(:left_chat, "chat:lobby")
      |> ChatWidget.assign_widget(:right_chat, "chat:lobby")

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <ChatWidget.render state={@left_chat} />
    <ChatWidget.render state={@right_chat} />
    """
  end
end

defmodule ShoddyPhoenix.Test.ChatLive do
  @moduledoc false
  # This LiveView has two instances of the chat widget on one topic. The
  # session of each test gives the topic, so the tests do not share a topic.
  # The other callbacks exist only for the tests.
  use Phoenix.LiveView

  alias ShoddyPhoenix.Test.ChatWidget

  def mount(_params, %{"topic" => topic}, socket) do
    socket =
      socket
      |> assign(:pings, 0)
      |> ChatWidget.assign_widget(:left_chat, topic)
      |> ChatWidget.assign_widget(:right_chat, topic)

    {:ok, socket}
  end

  def handle_event("remove-left", _params, socket) do
    {:noreply, ChatWidget.remove_widget(socket, :left_chat)}
  end

  def handle_event("chatter:ping", _params, socket) do
    {:noreply, update(socket, :pings, &(&1 + 1))}
  end

  # This function has a clause for one message only. A message of the widget
  # reaches it only if the hook of the widget does not halt that message, and
  # the LiveView then crashes.
  def handle_info(:ping, socket), do: {:noreply, update(socket, :pings, &(&1 + 1))}

  def render(assigns) do
    ~H"""
    <p id="pings">pings {@pings}</p>
    <ChatWidget.render :if={@left_chat} state={@left_chat} />
    <ChatWidget.render state={@right_chat} />
    """
  end
end

defmodule ShoddyPhoenix.Test.ReplyLive do
  @moduledoc false
  # The handler of the widget "probe" replies to one event, and it returns a
  # wrong value for another event. The event "unroute" stops the routing, and
  # the LiveView then receives the event "probe:count".
  use Phoenix.LiveView

  alias ShoddyPhoenix.LiveView.Widgets

  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:receiver, "widget") |> Widgets.route_events("probe", &handle_probe/3)}
  end

  defp handle_probe("count", _params, socket), do: {:reply, %{count: 1}, socket}
  defp handle_probe("wrong", _params, socket), do: {:ok, socket}

  def handle_event("unroute", _params, socket), do: {:noreply, Widgets.unroute_events(socket, "probe")}
  def handle_event("probe:count", _params, socket), do: {:noreply, assign(socket, :receiver, "LiveView")}

  def render(assigns), do: ~H"<p>Received by {@receiver}</p>"
end

defmodule ShoddyPhoenix.Test.HookOrderLive do
  @moduledoc false
  # Each hook adds its label to the assign :order. The third call of
  # put_hook/4 replaces the hook :first.
  use Phoenix.LiveView

  alias ShoddyPhoenix.LiveView

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:order, [])
      |> LiveView.put_hook(:first, :handle_event, record(:first))
      |> LiveView.put_hook(:second, :handle_event, record(:second))
      |> LiveView.put_hook(:first, :handle_event, record(:replacement))

    {:ok, socket}
  end

  defp record(label) do
    fn _event, _params, socket -> {:cont, update(socket, :order, &(&1 ++ [label]))} end
  end

  def handle_event("go", _params, socket), do: {:noreply, socket}

  def render(assigns), do: ~H|<p id="order">{Enum.join(@order, " ")}</p>|
end

defmodule ShoddyPhoenix.Test.ParamsHookLive do
  @moduledoc false
  # This LiveView attaches a :handle_params hook with put_hook/4.
  use Phoenix.LiveView

  alias ShoddyPhoenix.LiveView

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:hooked, false)
      |> LiveView.put_hook(:params, :handle_params, fn _params, _uri, socket ->
        {:cont, assign(socket, :hooked, true)}
      end)

    {:ok, socket}
  end

  def render(assigns), do: ~H"<p>hooked {@hooked}</p>"
end

defmodule ShoddyPhoenix.Test.NestedLive do
  @moduledoc false
  # This LiveView renders another LiveView as a nested LiveView. The session
  # selects the nested LiveView from a fixed list.
  use Phoenix.LiveView

  alias ShoddyPhoenix.Test.GuideChatLive
  alias ShoddyPhoenix.Test.ParamsHookLive

  @children %{
    "params-hook" => ParamsHookLive,
    "guide-chat" => GuideChatLive
  }

  def mount(_params, %{"child" => child}, socket) do
    {:ok, assign(socket, :child, Map.fetch!(@children, child))}
  end

  def render(assigns), do: ~H|<div>{live_render(@socket, @child, id: "nested")}</div>|
end
