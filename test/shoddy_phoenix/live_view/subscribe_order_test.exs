defmodule ShoddyPhoenix.LiveView.SubscribeOrderTest do
  # These tests share the store ShoddyPhoenix.Test.Messages and the topic
  # "messages". Thus they do not run at the same time as other tests.
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias ShoddyPhoenix.Test.Endpoint
  alias ShoddyPhoenix.Test.Messages

  @endpoint Endpoint

  setup do
    Messages.reset()
    Messages.post(%{id: 1, text: "First"})
    :ok
  end

  defp texts(view) do
    ~r{<p>([^<]*)</p>} |> Regex.scan(render(view), capture: :all_but_first) |> List.flatten()
  end

  describe "a LiveView that reads and then subscribes" do
    test "loses a change between the read and the subscription" do
      Messages.change_on_next_read(:after, %{id: 2, text: "Second"})

      {:ok, view, _html} = live(build_conn(), "/read-first")

      assert texts(view) == ["First"]
      assert Enum.map(Messages.list_recent(), & &1.text) == ["Second", "First"]
    end
  end

  describe "a LiveView that subscribes and then reads" do
    test "reads a change between the subscription and the read, and also receives its message" do
      Messages.change_on_next_read(:before, %{id: 2, text: "Second"})

      {:ok, view, _html} = live(build_conn(), "/append")

      assert texts(view) == ["Second", "Second", "First"]
    end
  end

  describe "the example of ShoddyPhoenix.LiveView" do
    test "shows the messages of the read and each later message" do
      {:ok, view, html} = live(build_conn(), "/subscribe")
      assert html =~ "<p>First</p>"

      Messages.post(%{id: 2, text: "Second"})

      assert texts(view) == ["Second", "First"]
    end

    test "shows a change between the subscription and the read one time" do
      Messages.change_on_next_read(:before, %{id: 2, text: "Second"})

      {:ok, view, _html} = live(build_conn(), "/subscribe")

      assert texts(view) == ["Second", "First"]
    end

    test "replaces a message that it already shows" do
      {:ok, view, _html} = live(build_conn(), "/subscribe")

      Messages.post(%{id: 1, text: "First, changed"})

      assert texts(view) == ["First, changed"]
    end

    test "subscribes only the process of the LiveView" do
      {:ok, view, _html} = live(build_conn(), "/subscribe")

      Messages.post(%{id: 2, text: "Second"})

      assert render(view) =~ "<p>Second</p>"
      refute_received {:new_message, _message}
    end
  end
end
