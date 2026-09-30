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

    property "selects the same slot when some tests are functions of arity 0" do
      check all(
              values <- list_of(test_value(), max_length: 8),
              lazy? <- list_of(boolean(), length: length(values))
            ) do
        tests =
          values
          |> Enum.zip(lazy?)
          |> Enum.map(fn {value, lazy?} -> if lazy?, do: fn -> value end, else: value end)

        assigns = %{tests: Enum.with_index(tests)}

        html =
          rendered_to_string(~H"""
          <.choose>
            <:when :for={{test, index} <- @tests} test={test}>{index}</:when>
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
  end

  describe "switch/1" do
    property "renders the first case with a value that is strictly equal, or the otherwise slot" do
      check all(
              value <- one_of([integer(0..3), float(min: 0.0, max: 3.0), atom(:alphanumeric)]),
              cases <- list_of(one_of([integer(0..3), constant(1.0), atom(:alphanumeric)]), max_length: 8)
            ) do
        assigns = %{value: value, cases: Enum.with_index(cases)}

        html =
          rendered_to_string(~H"""
          <.switch value={@value}>
            <:case :for={{case_value, index} <- @cases} value={case_value}>{index}</:case>
            <:otherwise>none</:otherwise>
          </.switch>
          """)

        expected =
          case Enum.find_index(cases, &(&1 === value)) do
            nil -> "none"
            index -> Integer.to_string(index)
          end

        assert html == expected
      end
    end
  end

  describe "result/1" do
    property "passes the value of an ok result and the reason of an error result to the slot" do
      check all(
              tag <- member_of([:ok, :error]),
              payload <- one_of([integer(), atom(:alphanumeric), boolean()])
            ) do
        assigns = %{result: {tag, payload}, payload: payload}

        html =
          rendered_to_string(~H"""
          <.result value={@result}>
            <:ok :let={value}>ok {value === @payload}</:ok>
            <:error :let={reason}>error {reason === @payload}</:error>
          </.result>
          """)

        assert html == "#{tag} true"
      end
    end
  end

  describe "wrap_if/1" do
    property "puts the content into the wrapper only for a truthy test" do
      check all(test <- test_value()) do
        assigns = %{test: test}

        html =
          rendered_to_string(
            ~H"<.wrap_if test={@test}><:wrapper :let={content}>[{render_slot(content)}]</:wrapper>x</.wrap_if>"
          )

        assert html == if(test, do: "[x]", else: "x")
      end
    end
  end

  describe "each/1" do
    property "renders the content for each item in order, or the empty slot" do
      check all(items <- list_of(integer(), max_length: 10)) do
        assigns = %{items: items}

        html =
          rendered_to_string(~H"<.each :let={item} items={@items}>[{item}]<:empty>none</:empty></.each>")

        expected = if items == [], do: "none", else: Enum.map_join(items, &"[#{&1}]")
        assert html == expected
      end
    end
  end
end
