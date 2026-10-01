defmodule ShoddyPhoenix.LiveView.SubscriptionsTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveComponent.CID
  alias Phoenix.LiveView.Socket
  alias ShoddyPhoenix.LiveView.Subscriptions
  alias ShoddyPhoenix.Test.PubSub

  # The type checker of Elixir can warn about a literal that a test gives to
  # a function on purpose, such as a value that is not a socket. This helper
  # returns its argument, and the type checker cannot see through it.
  defp opaque(value), do: Process.get({__MODULE__, :unset}, value)

  # Phoenix.LiveView.connected?/1 is true for a socket with a transport
  # process. The test process is then the process of the LiveView, so it
  # receives the messages of each subscription.
  defp connected_socket, do: %Socket{transport_pid: self()}

  # Each test uses its own topic, so tests that run at the same time do not
  # receive the messages of another test.
  defp new_topic, do: "subscriptions-test:#{System.unique_integer([:positive])}"

  # This helper broadcasts one message, and it returns the number of copies
  # that the test process received. The broadcast is local, so each copy is
  # in the mailbox when broadcast/3 returns.
  defp copies(topic) do
    ref = make_ref()
    :ok = Phoenix.PubSub.broadcast(PubSub, topic, {:probe, ref})
    count(ref, 0)
  end

  defp count(ref, total) do
    receive do
      {:probe, ^ref} -> count(ref, total + 1)
    after
      0 -> total
    end
  end

  # Phoenix.PubSub raises the same error for a wrong PubSub server or topic.
  # This helper also checks that the function of this module raises it.
  defp assert_clause_error(function, call) do
    error = assert_raise FunctionClauseError, call
    assert {error.module, error.function} == {Subscriptions, function}
  end

  describe "subscribe/4" do
    test "gives the process one subscription for two owners of a topic" do
      topic = new_topic()

      connected_socket()
      |> Subscriptions.subscribe(PubSub, topic, :left)
      |> Subscriptions.subscribe(PubSub, topic, :right)

      assert copies(topic) == 1
    end

    test "changes nothing for a second call with the same owner" do
      topic = new_topic()

      connected_socket()
      |> Subscriptions.subscribe(PubSub, topic, :left)
      |> Subscriptions.subscribe(PubSub, topic, :left)
      |> Subscriptions.unsubscribe(PubSub, topic, :left)

      assert copies(topic) == 0
    end

    test "keeps the owners of each topic separate" do
      first = new_topic()
      second = new_topic()

      connected_socket()
      |> Subscriptions.subscribe(PubSub, first, :left)
      |> Subscriptions.subscribe(PubSub, second, :left)
      |> Subscriptions.unsubscribe(PubSub, first, :left)

      assert copies(first) == 0
      assert copies(second) == 1
    end

    test "returns the socket and does nothing for a socket that is not connected" do
      topic = new_topic()
      socket = %Socket{}

      assert Subscriptions.subscribe(socket, PubSub, topic, :left) === socket
      assert copies(topic) == 0
    end

    test "raises ArgumentError for the socket of a LiveComponent" do
      socket = %Socket{transport_pid: self(), assigns: %{__changed__: %{}, myself: %CID{cid: 1}}}

      assert_raise ArgumentError, ~r"subscribe/4 does not accept the socket of a LiveComponent", fn ->
        Subscriptions.subscribe(socket, PubSub, new_topic(), :left)
      end
    end

    test "raises FunctionClauseError for a wrong socket, PubSub server or topic" do
      assert_clause_error(:subscribe, fn -> Subscriptions.subscribe(opaque(%{}), PubSub, new_topic(), :left) end)

      assert_clause_error(:subscribe, fn ->
        Subscriptions.subscribe(connected_socket(), opaque("PubSub"), new_topic(), :left)
      end)

      assert_clause_error(:subscribe, fn ->
        Subscriptions.subscribe(connected_socket(), PubSub, opaque(:topic), :left)
      end)
    end
  end

  describe "unsubscribe/4" do
    test "keeps the subscription until the last owner unsubscribes" do
      topic = new_topic()

      socket =
        connected_socket()
        |> Subscriptions.subscribe(PubSub, topic, :left)
        |> Subscriptions.subscribe(PubSub, topic, :right)
        |> Subscriptions.unsubscribe(PubSub, topic, :left)

      assert copies(topic) == 1

      Subscriptions.unsubscribe(socket, PubSub, topic, :right)

      assert copies(topic) == 0
    end

    test "does not unsubscribe for an owner that is not an owner of the topic" do
      topic = new_topic()
      :ok = Phoenix.PubSub.subscribe(PubSub, topic)

      Subscriptions.unsubscribe(connected_socket(), PubSub, topic, :left)

      assert copies(topic) == 1
    end

    test "does nothing for an owner that is not an owner of the topic" do
      topic = new_topic()

      connected_socket()
      |> Subscriptions.subscribe(PubSub, topic, :left)
      |> Subscriptions.unsubscribe(PubSub, topic, :right)

      assert copies(topic) == 1
    end

    test "returns the socket and does nothing for a socket that is not connected" do
      topic = new_topic()
      Subscriptions.subscribe(connected_socket(), PubSub, topic, :left)
      socket = %Socket{}

      assert Subscriptions.unsubscribe(socket, PubSub, topic, :left) === socket
      assert copies(topic) == 1
    end

    test "raises ArgumentError for the socket of a LiveComponent" do
      socket = %Socket{transport_pid: self(), assigns: %{__changed__: %{}, myself: %CID{cid: 1}}}

      assert_raise ArgumentError, ~r"unsubscribe/4 does not accept the socket of a LiveComponent", fn ->
        Subscriptions.unsubscribe(socket, PubSub, new_topic(), :left)
      end
    end

    test "raises FunctionClauseError for a wrong socket, PubSub server or topic" do
      assert_clause_error(:unsubscribe, fn -> Subscriptions.unsubscribe(opaque(%{}), PubSub, new_topic(), :left) end)

      assert_clause_error(:unsubscribe, fn ->
        Subscriptions.unsubscribe(connected_socket(), opaque("PubSub"), new_topic(), :left)
      end)

      assert_clause_error(:unsubscribe, fn ->
        Subscriptions.unsubscribe(connected_socket(), PubSub, opaque(:topic), :left)
      end)
    end
  end
end
