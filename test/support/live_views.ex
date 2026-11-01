defmodule ShoddyPhoenix.Test.Probe do
  @moduledoc false
  # Each LiveView of the tests calls report/3 in its callbacks. The test
  # process then receives one message that tells which function of
  # ShoddyPhoenix.LiveView called its function, and in which process.
  alias ShoddyPhoenix.LiveView

  def report(socket, test_pid, callback) do
    socket
    |> LiveView.when_connected(fn socket ->
      send(test_pid, {callback, :connected, self()})
      socket
    end)
    |> LiveView.when_not_connected(fn socket ->
      send(test_pid, {callback, :not_connected, self()})
      socket
    end)
  end
end

defmodule ShoddyPhoenix.Test.ProbeHook do
  @moduledoc false
  import Shoddy.Tagging, only: [cont: 1]

  alias ShoddyPhoenix.Test.Probe

  def on_mount(:default, _params, %{"test_pid" => test_pid}, socket) do
    socket |> Probe.report(test_pid, :on_mount) |> cont()
  end
end

defmodule ShoddyPhoenix.Test.ProbeComponent do
  @moduledoc false
  use Phoenix.LiveComponent

  import Shoddy.Tagging, only: [ok: 1]

  alias ShoddyPhoenix.Test.Probe

  def update(assigns, socket) do
    socket |> assign(assigns) |> Probe.report(assigns.test_pid, :component_update) |> ok()
  end

  def render(assigns), do: ~H"<p>Component</p>"
end

defmodule ShoddyPhoenix.Test.ProbeLive do
  @moduledoc false
  use Phoenix.LiveView

  import Shoddy.Tagging, only: [noreply: 1, ok: 1]

  alias ShoddyPhoenix.Test.Probe
  alias ShoddyPhoenix.Test.ProbeComponent

  def mount(_params, %{"test_pid" => test_pid}, socket) do
    socket |> assign(:test_pid, test_pid) |> Probe.report(test_pid, :mount) |> ok()
  end

  def handle_params(_params, _uri, socket) do
    socket |> Probe.report(socket.assigns.test_pid, :handle_params) |> noreply()
  end

  def handle_event("probe", _params, socket) do
    socket |> Probe.report(socket.assigns.test_pid, :handle_event) |> noreply()
  end

  def handle_info(:probe, socket) do
    socket |> Probe.report(socket.assigns.test_pid, :handle_info) |> noreply()
  end

  def render(assigns) do
    ~H"""
    <.live_component module={ProbeComponent} id="probe" test_pid={@test_pid} />
    """
  end
end

defmodule ShoddyPhoenix.Test.PlaceholderLive do
  @moduledoc false
  # This LiveView is the example of the documentation of
  # ShoddyPhoenix.LiveView.when_not_connected/2.
  use Phoenix.LiveView

  alias ShoddyPhoenix.LiveView

  def mount(_params, _session, socket) do
    socket =
      socket
      |> LiveView.when_not_connected(fn socket -> render_with(socket, &loading/1) end)
      |> LiveView.when_connected(&assign(&1, :rows, ["Row one", "Row two"]))

    {:ok, socket}
  end

  defp loading(assigns), do: ~H"<p>Loading</p>"

  def render(assigns), do: ~H"<p :for={row <- @rows}>{row}</p>"
end

defmodule ShoddyPhoenix.Test.LostAssignLive do
  @moduledoc false
  # This LiveView assigns the title only in the disconnected render.
  use Phoenix.LiveView

  import Shoddy.Tagging, only: [ok: 1]

  alias ShoddyPhoenix.LiveView

  def mount(_params, _session, socket) do
    socket |> LiveView.when_not_connected(&assign(&1, :title, "Disconnected title")) |> ok()
  end

  def render(assigns), do: ~H"<h1>{@title}</h1>"
end

defmodule ShoddyPhoenix.Test.AsyncLive do
  @moduledoc false
  # Each task tells the test process whether the socket was connected when
  # the LiveView started the task.
  use Phoenix.LiveView

  import Shoddy.Tagging, only: [noreply: 1, ok: 1]

  def mount(_params, %{"test_pid" => test_pid}, socket) do
    connected? = connected?(socket)

    socket =
      socket
      |> assign_async(:data, fn ->
        send(test_pid, {:assign_async, connected?})
        ok(%{data: "Loaded"})
      end)
      |> start_async(:job, fn -> send(test_pid, {:start_async, connected?}) end)

    ok(socket)
  end

  def handle_async(:job, _result, socket), do: noreply(socket)

  def render(assigns) do
    ~H"""
    <p :if={@data.loading}>Loading data</p>
    <p :if={@data.ok?}>{@data.result}</p>
    """
  end
end

defmodule ShoddyPhoenix.Test.SubscribeLive do
  @moduledoc false
  # This LiveView is the example of the documentation of
  # ShoddyPhoenix.LiveView.
  use Phoenix.LiveView

  alias ShoddyPhoenix.LiveView
  alias ShoddyPhoenix.Test.Messages
  alias ShoddyPhoenix.Test.PubSub

  def mount(_params, _session, socket) do
    socket =
      socket
      |> LiveView.when_connected(&subscribe/1)
      |> assign(:messages, Messages.list_recent())

    {:ok, socket}
  end

  def handle_info({:new_message, message}, socket) do
    {:noreply, update(socket, :messages, &put_message(&1, message))}
  end

  defp subscribe(socket) do
    Phoenix.PubSub.subscribe(PubSub, "messages")
    socket
  end

  # The read of mount/3 can already contain the message. Then this function
  # replaces that message, and it does not add the message a second time.
  defp put_message(messages, message) do
    [message | Enum.reject(messages, &(&1.id == message.id))]
  end

  def render(assigns), do: ~H"<p :for={message <- @messages}>{message.text}</p>"
end

defmodule ShoddyPhoenix.Test.ConnectedOnlyLive do
  @moduledoc false
  # This LiveView assigns the messages only in the connected render, but its
  # template needs them in each render.
  use Phoenix.LiveView

  import Shoddy.Tagging, only: [ok: 1]

  alias ShoddyPhoenix.LiveView

  def mount(_params, _session, socket) do
    socket |> LiveView.when_connected(&assign(&1, :messages, [])) |> ok()
  end

  def render(assigns), do: ~H"<p :for={message <- @messages}>{message}</p>"
end
