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
  alias ShoddyPhoenix.Test.Probe

  def on_mount(:default, _params, %{"test_pid" => test_pid}, socket) do
    {:cont, Probe.report(socket, test_pid, :on_mount)}
  end
end

defmodule ShoddyPhoenix.Test.ProbeComponent do
  @moduledoc false
  use Phoenix.LiveComponent

  alias ShoddyPhoenix.Test.Probe

  def update(assigns, socket) do
    {:ok, socket |> assign(assigns) |> Probe.report(assigns.test_pid, :component_update)}
  end

  def render(assigns), do: ~H"<p>Component</p>"
end

defmodule ShoddyPhoenix.Test.ProbeLive do
  @moduledoc false
  use Phoenix.LiveView

  alias ShoddyPhoenix.Test.Probe
  alias ShoddyPhoenix.Test.ProbeComponent

  def mount(_params, %{"test_pid" => test_pid}, socket) do
    {:ok, socket |> assign(:test_pid, test_pid) |> Probe.report(test_pid, :mount)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, Probe.report(socket, socket.assigns.test_pid, :handle_params)}
  end

  def handle_event("probe", _params, socket) do
    {:noreply, Probe.report(socket, socket.assigns.test_pid, :handle_event)}
  end

  def handle_info(:probe, socket) do
    {:noreply, Probe.report(socket, socket.assigns.test_pid, :handle_info)}
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

  alias ShoddyPhoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, LiveView.when_not_connected(socket, &assign(&1, :title, "Disconnected title"))}
  end

  def render(assigns), do: ~H"<h1>{@title}</h1>"
end

defmodule ShoddyPhoenix.Test.AsyncLive do
  @moduledoc false
  # Each task tells the test process whether the socket was connected when
  # the LiveView started the task.
  use Phoenix.LiveView

  def mount(_params, %{"test_pid" => test_pid}, socket) do
    connected? = connected?(socket)

    socket =
      socket
      |> assign_async(:data, fn ->
        send(test_pid, {:assign_async, connected?})
        {:ok, %{data: "Loaded"}}
      end)
      |> start_async(:job, fn -> send(test_pid, {:start_async, connected?}) end)

    {:ok, socket}
  end

  def handle_async(:job, _result, socket), do: {:noreply, socket}

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
  alias ShoddyPhoenix.Test.PubSub

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:messages, [])
      |> LiveView.when_connected(&subscribe/1)

    {:ok, socket}
  end

  def handle_info({:new_message, message}, socket) do
    {:noreply, update(socket, :messages, &[message | &1])}
  end

  defp subscribe(socket) do
    Phoenix.PubSub.subscribe(PubSub, "messages")
    socket
  end

  def render(assigns), do: ~H"<p :for={message <- @messages}>{message}</p>"
end

defmodule ShoddyPhoenix.Test.ConnectedOnlyLive do
  @moduledoc false
  # This LiveView assigns the messages only in the connected render, but its
  # template needs them in each render.
  use Phoenix.LiveView

  alias ShoddyPhoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, LiveView.when_connected(socket, &assign(&1, :messages, []))}
  end

  def render(assigns), do: ~H"<p :for={message <- @messages}>{message}</p>"
end
