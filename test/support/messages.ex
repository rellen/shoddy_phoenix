defmodule ShoddyPhoenix.Test.Messages do
  @moduledoc false
  # This module is the store of messages for the example of
  # ShoddyPhoenix.LiveView. post/1 adds a message, and it broadcasts the
  # message on the topic "messages".
  #
  # A test can make one change during the next read of a LiveView, with
  # change_on_next_read/2. The change occurs before the read or after it.
  # Only a process other than the test process starts the change. Thus the
  # disconnected render, which runs in the test process, does not use it.
  use Agent

  alias ShoddyPhoenix.Test.PubSub

  def start_link(_opts) do
    Agent.start_link(fn -> %{messages: [], change: nil} end, name: __MODULE__)
  end

  # Removes each message and each change. Each test calls it first.
  def reset, do: Agent.update(__MODULE__, fn _state -> %{messages: [], change: nil} end)

  def list_recent do
    change(:before)
    messages = Agent.get(__MODULE__, & &1.messages)
    change(:after)
    messages
  end

  def post(message) do
    Agent.update(__MODULE__, &%{&1 | messages: [message | &1.messages]})
    Phoenix.PubSub.broadcast(PubSub, "messages", {:new_message, message})
  end

  def change_on_next_read(position, message) when position in [:before, :after] do
    owner = self()
    Agent.update(__MODULE__, &%{&1 | change: {position, message, owner}})
  end

  defp change(position) do
    reader = self()

    pending =
      Agent.get_and_update(__MODULE__, fn
        %{change: {^position, message, owner}} = state when owner != reader -> {message, %{state | change: nil}}
        state -> {nil, state}
      end)

    if pending, do: post(pending)
  end
end
