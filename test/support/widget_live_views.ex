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

  import Shoddy.Tagging, only: [noreply: 1, ok: 1]

  alias ShoddyPhoenix.Test.ChatWidget

  def mount(_params, %{"topic" => topic}, socket) do
    socket
    |> assign(:pings, 0)
    |> ChatWidget.assign_widget(:left_chat, topic)
    |> ChatWidget.assign_widget(:right_chat, topic)
    |> ok()
  end

  def handle_event("remove-left", _params, socket) do
    socket |> ChatWidget.remove_widget(:left_chat) |> noreply()
  end

  def handle_event("chatter:ping", _params, socket) do
    socket |> update(:pings, &(&1 + 1)) |> noreply()
  end

  # This function has a clause for one message only. A message of the widget
  # reaches it only if the hook of the widget does not halt that message, and
  # the LiveView then crashes.
  def handle_info(:ping, socket), do: socket |> update(:pings, &(&1 + 1)) |> noreply()

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

  import Shoddy.Tagging, only: [noreply: 1, ok: 1]

  alias ShoddyPhoenix.LiveView.Widgets

  def mount(_params, _session, socket) do
    socket |> assign(:receiver, "widget") |> Widgets.route_events("probe", &handle_probe/3) |> ok()
  end

  # Shoddy.Tagging.reply/2 takes the reply first, so a pipeline of the socket
  # into it puts the socket in the place of the reply. Thus this clause writes
  # the tuple.
  defp handle_probe("count", _params, socket), do: {:reply, %{count: 1}, socket}
  defp handle_probe("wrong", _params, socket), do: {:ok, socket}

  def handle_event("unroute", _params, socket), do: socket |> Widgets.unroute_events("probe") |> noreply()
  def handle_event("probe:count", _params, socket), do: socket |> assign(:receiver, "LiveView") |> noreply()

  def render(assigns), do: ~H"<p>Received by {@receiver}</p>"
end

defmodule ShoddyPhoenix.Test.HookOrderLive do
  @moduledoc false
  # Each hook adds its label to the assign :order. The third call of
  # put_hook/4 replaces the hook :first.
  use Phoenix.LiveView

  import Shoddy.Tagging, only: [cont: 1, noreply: 1, ok: 1]

  alias ShoddyPhoenix.LiveView

  def mount(_params, _session, socket) do
    socket
    |> assign(:order, [])
    |> LiveView.put_hook(:first, :handle_event, record(:first))
    |> LiveView.put_hook(:second, :handle_event, record(:second))
    |> LiveView.put_hook(:first, :handle_event, record(:replacement))
    |> ok()
  end

  defp record(label) do
    fn _event, _params, socket -> socket |> update(:order, &(&1 ++ [label])) |> cont() end
  end

  def handle_event("go", _params, socket), do: noreply(socket)

  def render(assigns), do: ~H|<p id="order">{Enum.join(@order, " ")}</p>|
end

defmodule ShoddyPhoenix.Test.ParamsHookLive do
  @moduledoc false
  # This LiveView attaches a :handle_params hook with put_hook/4.
  use Phoenix.LiveView

  import Shoddy.Tagging, only: [cont: 1, ok: 1]

  alias ShoddyPhoenix.LiveView

  def mount(_params, _session, socket) do
    socket
    |> assign(:hooked, false)
    |> LiveView.put_hook(:params, :handle_params, fn _params, _uri, socket ->
      socket |> assign(:hooked, true) |> cont()
    end)
    |> ok()
  end

  def render(assigns), do: ~H"<p>hooked {@hooked}</p>"
end

defmodule ShoddyPhoenix.Test.NestedLive do
  @moduledoc false
  # This LiveView renders another LiveView as a nested LiveView. The session
  # selects the nested LiveView from a fixed list.
  use Phoenix.LiveView

  import Shoddy.Tagging, only: [ok: 1]

  alias ShoddyPhoenix.Test.GuideChatLive
  alias ShoddyPhoenix.Test.ParamsHookLive

  @children %{
    "params-hook" => ParamsHookLive,
    "guide-chat" => GuideChatLive
  }

  def mount(_params, %{"child" => child}, socket) do
    socket |> assign(:child, Map.fetch!(@children, child)) |> ok()
  end

  def render(assigns), do: ~H|<div>{live_render(@socket, @child, id: "nested")}</div>|
end

defmodule ShoddyPhoenix.Test.ActionsLive do
  @moduledoc false
  # The handler of the widget "probe" has a clause for the action "count"
  # only. The option :actions halts each other action, so the LiveView does
  # not crash. The LiveView counts each event that reaches it.
  use Phoenix.LiveView

  import Shoddy.Tagging, only: [noreply: 1, ok: 1]

  alias ShoddyPhoenix.LiveView.Widgets

  def mount(_params, _session, socket) do
    socket
    |> assign(widget: 0, live_view: 0)
    |> Widgets.route_events("probe", &handle_probe/3, actions: ["count"])
    |> ok()
  end

  defp handle_probe("count", _params, socket), do: socket |> update(:widget, &(&1 + 1)) |> noreply()

  def handle_event(_event, _params, socket), do: socket |> update(:live_view, &(&1 + 1)) |> noreply()

  def render(assigns), do: ~H"<p>widget {@widget} live_view {@live_view}</p>"
end

defmodule ShoddyPhoenix.Test.CountersWidget do
  @moduledoc false
  # Each instance of this widget is a counter in an assign of the LiveView.
  # The events name the instance in the parameter "id", and the handler has
  # a clause for the action "inc" only.
  use Phoenix.Component

  import Shoddy.Tagging, only: [noreply: 1]

  alias ShoddyPhoenix.LiveView.Widgets

  defstruct [:key, count: 0]

  def assign_widget(socket, key) do
    socket
    |> assign(key, %__MODULE__{key: key})
    |> Widgets.route_instance_events("counter", __MODULE__, &handle_event/4, param: "id", actions: ["inc"])
  end

  defp handle_event("inc", _params, {key, counter}, socket) do
    socket |> assign(key, %{counter | count: counter.count + 1}) |> noreply()
  end
end

defmodule ShoddyPhoenix.Test.CountersLive do
  @moduledoc false
  # This LiveView has two counters, and it counts each event that reaches
  # it.
  use Phoenix.LiveView

  import Shoddy.Tagging, only: [noreply: 1, ok: 1]

  alias ShoddyPhoenix.Test.CountersWidget

  def mount(_params, _session, socket) do
    socket
    |> assign(:live_view, 0)
    |> CountersWidget.assign_widget(:left)
    |> CountersWidget.assign_widget(:right)
    |> ok()
  end

  def handle_event(_event, _params, socket), do: socket |> update(:live_view, &(&1 + 1)) |> noreply()

  def render(assigns), do: ~H"<p>left {@left.count} right {@right.count} live_view {@live_view}</p>"
end
