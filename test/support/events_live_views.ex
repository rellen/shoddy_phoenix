defmodule ShoddyPhoenix.Test.EventsComponent do
  @moduledoc false
  # This LiveComponent sends its event to itself with phx-target={@myself}.
  use Phoenix.LiveComponent
  use ShoddyPhoenix.LiveView.Events

  def mount(socket), do: {:ok, assign(socket, :likes, 0)}

  def render(assigns) do
    ~H"""
    <div>
      <p id="likes">likes {@likes}</p>
      <button phx-click={event("like")} phx-target={@myself}>Like</button>
    </div>
    """
  end

  def handle_event("like", _params, socket), do: {:noreply, update(socket, :likes, &(&1 + 1))}
end

defmodule ShoddyPhoenix.Test.CounterLive do
  @moduledoc false
  # This LiveView is the example of the documentation of
  # ShoddyPhoenix.LiveView.Events, with the correct name of each event.
  use Phoenix.LiveView
  use ShoddyPhoenix.LiveView.Events

  alias ShoddyPhoenix.Test.EventsComponent

  def mount(_params, _session, socket), do: {:ok, assign(socket, :count, 0)}

  def render(assigns) do
    ~H"""
    <p id="count">count {@count}</p>
    <button phx-click={event("inc")}>+</button>
    <button phx-click={event("dec")}>-</button>
    <.live_component module={EventsComponent} id="likes" />
    """
  end

  def handle_event("inc", _params, socket), do: {:noreply, update(socket, :count, &(&1 + 1))}
  def handle_event("dec", _params, socket), do: {:noreply, update(socket, :count, &(&1 - 1))}
end
