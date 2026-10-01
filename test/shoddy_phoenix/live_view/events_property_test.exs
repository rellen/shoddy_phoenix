defmodule ShoddyPhoenix.LiveView.EventsPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias ShoddyPhoenix.Test.Warnings

  # Compiles a module that uses the names in event/1 and that has these
  # heads of handle_event/3. Returns the module and the warnings.
  defp compile(names, heads, opts \\ []) do
    module = Module.concat(__MODULE__, "M#{System.unique_integer([:positive])}")

    uses =
      for {name, index} <- Enum.with_index(names) do
        quote do
          def unquote(:"use_#{index}")(), do: event(unquote(name))
        end
      end

    clauses =
      for head <- heads do
        quote do
          def handle_event(unquote(head), _params, socket), do: socket
        end
      end

    code =
      quote do
        defmodule unquote(module) do
          use ShoddyPhoenix.LiveView.Events, unquote(opts)

          unquote_splicing(uses)
          unquote_splicing(clauses)
        end
      end

    warnings = Warnings.collect(fn -> Code.compile_quoted(code) end)
    {module, warnings}
  end

  defp missing(name), do: "for the event #{inspect(name)}\n"

  # A name from a small alphabet often occurs in two lists. A printable name
  # can contain a character that inspect/1 must escape.
  defp name, do: one_of([string([?a, ?b], max_length: 2), string(:printable, max_length: 6)])

  property "warns for each name that no literal clause handles, and only for it" do
    check all(handled <- list_of(name(), max_length: 4), used <- list_of(name(), max_length: 4)) do
      {_module, warnings} = compile(used, Enum.uniq(handled))

      for name <- used do
        assert warnings =~ missing(name) == name not in handled
      end
    end
  end

  property "accepts each name that starts with the prefix of a clause" do
    check all(prefix <- name(), name <- one_of([name(), map(name(), &(prefix <> &1))])) do
      head = quote do: unquote(prefix) <> _rest
      {_module, warnings} = compile([name], [head])

      assert warnings =~ missing(name) == not String.starts_with?(name, prefix)
    end
  end

  property "puts the prefix and a colon in front of the name, and checks the name alone" do
    check all(
            prefix <- filter(string(:printable, min_length: 1, max_length: 6), &(not String.contains?(&1, ":"))),
            name <- name(),
            handled? <- boolean()
          ) do
      heads = if handled?, do: [name], else: [prefix <> ":" <> name]
      {module, warnings} = compile([name], heads, prefix: prefix)

      assert module.use_0() == prefix <> ":" <> name
      assert warnings =~ missing(name) == not handled?
    end
  end
end
