defmodule ShoddyPhoenix.LiveView.WidgetsPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Shoddy.Tagging, only: [noreply: 1]

  alias Phoenix.LiveView.Lifecycle
  alias Phoenix.LiveView.Socket
  alias ShoddyPhoenix.LiveView.Widgets
  alias ShoddyPhoenix.Test.ChatWidget

  # The keys come from a fixed list, because LiveView reserves some assign
  # keys, such as :flash. Each assign contains an instance of the widget or a
  # value of another kind.
  @keys [:left_chat, :right_chat, :count, :title]

  defp assigns do
    list_of(
      tuple({
        member_of(@keys),
        one_of([
          map(member_of(["a", "b"]), &%ChatWidget{topic: &1}),
          integer(),
          constant(%URI{})
        ])
      }),
      max_length: 6
    )
  end

  # A name is the name of a key, another string, or a value of another kind.
  defp name do
    one_of([
      map(member_of(@keys), &Atom.to_string/1),
      string(:alphanumeric),
      constant(nil),
      integer()
    ])
  end

  property "finds an instance only for the name of a key with a struct of the widget" do
    check all(assigns <- assigns(), name <- name()) do
      socket = Phoenix.Component.assign(%Socket{}, assigns)

      expected =
        case Enum.find(Map.to_list(socket.assigns), fn {key, _value} -> Atom.to_string(key) === name end) do
          {key, %ChatWidget{} = instance} -> {:ok, {key, instance}}
          _other -> :error
        end

      assert Widgets.fetch_instance(socket, ChatWidget, name) == expected
    end
  end

  # LiveView keeps each :handle_event hook in the private data of the
  # socket. This helper returns the function of the only hook.
  defp hook(socket) do
    [%{function: function}] = socket.private.lifecycle.handle_event
    function
  end

  # The handler sends the action to the test process, so a property can see
  # whether the hook called the handler.
  defp handler(action, _params, socket) do
    send(self(), {:handled, action})
    noreply(socket)
  end

  defp instance_handler(action, _params, instance, socket) do
    send(self(), {:handled, action, instance})
    noreply(socket)
  end

  defp action, do: string([?a, ?b, ?:], max_length: 3)

  property "calls the handler only for an action in the list, and halts each event of the widget" do
    check all(actions <- list_of(action(), min_length: 1, max_length: 3), action <- action()) do
      socket = Widgets.route_events(%Socket{private: %{lifecycle: %Lifecycle{}}}, "w", &handler/3, actions: actions)

      assert {:halt, %Socket{}} = hook(socket).("w:" <> action, %{}, socket)

      if action in actions do
        assert_received {:handled, ^action}
      else
        refute_received {:handled, _action}
      end
    end
  end

  property "sends an event of another name to the LiveView, and does not call the handler" do
    check all(event <- string(:printable, max_length: 6), not String.starts_with?(event, "w:")) do
      socket = Widgets.route_events(%Socket{private: %{lifecycle: %Lifecycle{}}}, "w", &handler/3)

      assert {:cont, %Socket{}} = hook(socket).(event, %{}, socket)
      refute_received {:handled, _action}
    end
  end

  property "calls the instance handler only for a parameter that names an instance" do
    check all(assigns <- assigns(), name <- name()) do
      socket =
        %Socket{private: %{lifecycle: %Lifecycle{}}}
        |> Phoenix.Component.assign(assigns)
        |> Widgets.route_instance_events("w", ChatWidget, &instance_handler/4)

      assert {:halt, %Socket{}} = hook(socket).("w:go", %{"instance" => name}, socket)

      case Widgets.fetch_instance(socket, ChatWidget, name) do
        {:ok, instance} -> assert_received {:handled, "go", ^instance}
        :error -> refute_received {:handled, _action, _instance}
      end
    end
  end
end
