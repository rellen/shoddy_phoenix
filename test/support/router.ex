defmodule ShoddyPhoenix.Test.Router do
  @moduledoc false
  use Phoenix.Router, helpers: false

  import Phoenix.LiveView.Router

  alias ShoddyPhoenix.Test.AsyncLive
  alias ShoddyPhoenix.Test.ChatLive
  alias ShoddyPhoenix.Test.ConnectedOnlyLive
  alias ShoddyPhoenix.Test.GuideChatLive
  alias ShoddyPhoenix.Test.HookOrderLive
  alias ShoddyPhoenix.Test.LostAssignLive
  alias ShoddyPhoenix.Test.NestedLive
  alias ShoddyPhoenix.Test.ParamsHookLive
  alias ShoddyPhoenix.Test.PlaceholderLive
  alias ShoddyPhoenix.Test.ProbeHook
  alias ShoddyPhoenix.Test.ProbeLive
  alias ShoddyPhoenix.Test.ReplyLive
  alias ShoddyPhoenix.Test.SubscribeLive

  # Two routes go to ProbeLive, so a test can make a live navigation between
  # them.
  live_session :probe, on_mount: ProbeHook do
    live "/probe", ProbeLive
    live "/probe/again", ProbeLive
  end

  live_session :default do
    live "/placeholder", PlaceholderLive
    live "/lost-assign", LostAssignLive
    live "/async", AsyncLive
    live "/subscribe", SubscribeLive
    live "/connected-only", ConnectedOnlyLive
    live "/hook-order", HookOrderLive
    live "/params-hook", ParamsHookLive
    live "/chat", ChatLive
    live "/guide-chat", GuideChatLive
    live "/reply", ReplyLive
    live "/nested", NestedLive
  end
end
