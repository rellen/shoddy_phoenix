defmodule ShoddyPhoenix.ControlFlowPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Phoenix.Component
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import ShoddyPhoenix.ControlFlow

  defp test_value, do: one_of([constant(nil), constant(false), boolean(), integer(), atom(:alphanumeric)])

  describe "choose/1" do
    property "renders the first slot with a truthy test, or the otherwise slot" do
      check all(values <- list_of(test_value(), max_length: 8)) do
        assigns = %{values: Enum.with_index(values)}

        html =
          rendered_to_string(~H"""
          <.choose>
            <:when :for={{value, index} <- @values} test={value}>{index}</:when>
            <:otherwise>none</:otherwise>
          </.choose>
          """)

        expected =
          case Enum.find_index(values, & &1) do
            nil -> "none"
            index -> Integer.to_string(index)
          end

        assert html == expected
      end
    end

    property "binds the value of the selected test with :let" do
      check all(
              falsy_values <- list_of(member_of([nil, false]), max_length: 4),
              truthy_value <- one_of([constant(true), integer(), atom(:alphanumeric)]),
              other_values <- list_of(test_value(), max_length: 4)
            ) do
        values = falsy_values ++ [truthy_value | other_values]
        assigns = %{values: values}

        html =
          rendered_to_string(~H"""
          <.choose>
            <:when :for={value <- @values} :let={bound} test={value}>
              {if bound === value, do: "same", else: "different"}
            </:when>
          </.choose>
          """)

        assert String.trim(html) == "same"
      end
    end
  end
end
