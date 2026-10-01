defmodule ShoddyPhoenix.Test.Endpoint do
  @moduledoc false
  # The tests of ShoddyPhoenix.LiveView render LiveViews through this endpoint.
  # test/test_helper.exs gives its configuration, and it starts it.
  use Phoenix.Endpoint, otp_app: :shoddy_phoenix

  alias ShoddyPhoenix.Test.Router

  plug Router
end

defmodule ShoddyPhoenix.Test.ErrorHTML do
  @moduledoc false
  # The endpoint renders an error page with this module. A test can then
  # examine the exception of a render that fails.
  def render(template, _assigns), do: Phoenix.Controller.status_message_from_template(template)
end
