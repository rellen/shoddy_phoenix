defmodule ShoddyPhoenix.LiveView.SubscriptionsPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Phoenix.LiveView.Socket
  alias ShoddyPhoenix.LiveView.Subscriptions
  alias ShoddyPhoenix.Test.PubSub

  # A step subscribes or unsubscribes one owner of a small set of owners.
  defp steps do
    list_of(tuple({member_of([:subscribe, :unsubscribe]), member_of([:a, :b, :c])}), max_length: 12)
  end

  # This helper broadcasts one message, and it returns the number of copies
  # that the test process received.
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

  property "the process receives one copy while the topic has an owner, and no copy after the last owner" do
    check all(steps <- steps()) do
      topic = "subscriptions-property:#{System.unique_integer([:positive])}"

      Enum.reduce(steps, %Socket{transport_pid: self()}, fn
        {:subscribe, owner}, socket -> Subscriptions.subscribe(socket, PubSub, topic, owner)
        {:unsubscribe, owner}, socket -> Subscriptions.unsubscribe(socket, PubSub, topic, owner)
      end)

      owners =
        Enum.reduce(steps, MapSet.new(), fn
          {:subscribe, owner}, owners -> MapSet.put(owners, owner)
          {:unsubscribe, owner}, owners -> MapSet.delete(owners, owner)
        end)

      assert copies(topic) == if(MapSet.size(owners) == 0, do: 0, else: 1)

      # The test process stays alive between the runs of a property, so this
      # step removes the subscription of this run.
      Phoenix.PubSub.unsubscribe(PubSub, topic)
    end
  end

  property "a socket that is not connected never subscribes" do
    check all(steps <- steps()) do
      topic = "subscriptions-property:#{System.unique_integer([:positive])}"
      socket = %Socket{}

      result =
        Enum.reduce(steps, socket, fn
          {:subscribe, owner}, socket -> Subscriptions.subscribe(socket, PubSub, topic, owner)
          {:unsubscribe, owner}, socket -> Subscriptions.unsubscribe(socket, PubSub, topic, owner)
        end)

      assert result === socket
      assert copies(topic) == 0
    end
  end
end
