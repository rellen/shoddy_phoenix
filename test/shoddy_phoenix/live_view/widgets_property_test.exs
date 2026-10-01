defmodule ShoddyPhoenix.LiveView.WidgetsPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

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
end
