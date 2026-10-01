# This module is for LiveViews and LiveComponents, so it exists only with the
# optional dependency phoenix_live_view. Without that dependency, this file
# defines no module.
if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule ShoddyPhoenix.LiveView.Events do
    @moduledoc """
    A compile-time check of the event names of a LiveView.

    A template sends an event by its name, as in `phx-click="inc"`, and
    `handle_event/3` receives it. LiveView compares the two names only when the
    event arrives. A wrong name then raises `FunctionClauseError`, and the
    LiveView crashes.

    This module moves that comparison to the compile time. Write each event
    name with `event/1`:

    ```elixir
    defmodule MyAppWeb.CounterLive do
      use Phoenix.LiveView
      use ShoddyPhoenix.LiveView.Events

      def render(assigns) do
        ~H\"\"\"
        <button phx-click={event("inc")}>+</button>
        <button phx-click={event("decc")}>-</button>
        \"\"\"
      end

      def handle_event("inc", _params, socket), do: {:noreply, update(socket, :count, &(&1 + 1))}
      def handle_event("dec", _params, socket), do: {:noreply, update(socket, :count, &(&1 - 1))}
    end
    ```

    The compiler then gives a warning at the line of the wrong name:

    ```text
    warning: MyAppWeb.CounterLive has no clause of handle_event/3 for the event "decc"
    ```

    With `mix compile --warnings-as-errors`, the warning stops the compile.

    ## The check

    After the compiler compiles the module, the check compares each name of
    `event/1` with the first argument of each clause of `handle_event/3`.
    These clauses handle an event:

    - A clause with a literal string, such as `"inc"`, handles that name.
    - A clause with a prefix pattern, such as `"chat:" <> rest`, handles each
      name that starts with that prefix.
    - A clause with a pattern such as `"inc" = event` handles `"inc"`.

    A clause with another first argument, such as a variable, can handle each
    name. Then the module has no check, because the check cannot know which
    names that clause handles.

    The check reads the clauses of `handle_event/3` in the module itself. A
    widget can define that function as a private function. The check works in
    a LiveView, in a LiveComponent, and in a module of a widget.
    The template can be in the module or in a separate `.heex` file.

    ## What the check does not see

    - A name that is not a literal string. `event/1` accepts only a literal
      string, and it raises `ArgumentError` at the compile time for another
      value.
    - A name that a template writes as a plain string, such as
      `phx-click="inc"`.
    - An event that JavaScript sends, for example with `pushEvent` in a hook.
    - A function component in another module that sends an event to the
      LiveView. That component does not know the LiveView. Give the event name
      to the component as an attribute, and write the name with `event/1` in
      the LiveView.
    - A clause of `handle_event/3` that no template uses. JavaScript can send
      such an event, so the check does not warn about it.

    In a LiveComponent, an event without `phx-target={@myself}` goes to the
    LiveView of the component. Do not write the name of such an event with
    `event/1` in the component.

    ## The events of a widget

    A widget handles its events with `ShoddyPhoenix.LiveView.Widgets.route_events/3`.
    The hook of that function removes the name of the widget and the colon,
    and the handler receives the rest. Give the name of the widget with the
    option `:prefix`:

    ```elixir
    use ShoddyPhoenix.LiveView.Events, prefix: "chat"
    ```

    Then `event("send")` returns `"chat:send"`, and the check looks for a
    clause of `handle_event/3` for `"send"`. The prefix obeys the rules of the
    name of a widget: it is not empty, and it contains no colon.

    Give `event_prefix/0` to `route_events/3`. Then the name of the widget
    occurs one time only, and the two names cannot be different.

    The prefix must be a literal string. A module attribute is not
    permitted, because a formatter plugin such as Quokka can change such a
    `use` into code that does not compile.

    ## Usage

    This module exists only if your project has the dependency
    `phoenix_live_view`, version 1.2 or a later version before 2.0.

    To check each LiveView and each LiveComponent of an application, add the
    `use` to the functions `live_view/0` and `live_component/0` of
    `lib/my_app_web.ex`. A module that does not call `event/1` gets no
    warning. A second `use` in a module with the same prefix changes nothing.
    """

    @doc """
    Imports `event/1` and `event_prefix/0`, and adds the check to the module.

    The only option is `:prefix`, the name of a widget. The prefix must be a
    literal string that is not empty and that contains no colon. `use` raises
    `ArgumentError` for another prefix or for another option.

    A second `use` in the same module with the same prefix changes nothing,
    and the check runs one time. A second `use` with another prefix raises
    `ArgumentError`.
    """
    defmacro __using__(opts) do
      prefix = opts |> Keyword.validate!([:prefix]) |> Keyword.get(:prefix) |> prefix!()

      quote do
        import unquote(__MODULE__), only: [event: 1, event_prefix: 0]

        unquote(__MODULE__).__setup__(__MODULE__, unquote(prefix))
      end
    end

    @doc false
    # Adds the check to the module. A second use with the same prefix changes
    # nothing, so the check runs one time only.
    @spec __setup__(module(), String.t() | nil) :: :ok
    def __setup__(module, prefix) do
      cond do
        not Module.has_attribute?(module, :shoddy_phoenix_event_prefix) ->
          Module.register_attribute(module, :shoddy_phoenix_events, accumulate: true)
          Module.put_attribute(module, :shoddy_phoenix_event_prefix, prefix)
          Module.put_attribute(module, :after_compile, __MODULE__)

        Module.get_attribute(module, :shoddy_phoenix_event_prefix) == prefix ->
          :ok

        true ->
          raise ArgumentError,
                "#{inspect(module)} uses ShoddyPhoenix.LiveView.Events two times, with the prefixes " <>
                  "#{inspect(Module.get_attribute(module, :shoddy_phoenix_event_prefix))} and #{inspect(prefix)}. " <>
                  "Give one prefix."
      end

      :ok
    end

    @doc """
    Returns the name of an event, and records it for the check.

    `name` must be a literal string. Without the option `:prefix`, the
    function returns `name`. With the prefix `"chat"`, `event("send")`
    returns `"chat:send"`.

    ```heex
    <button phx-click={event("inc")}>+</button>
    ```

    `event/1` is a macro. It raises `ArgumentError` at the compile time for a
    `name` that is not a literal string, or for a module without
    `use ShoddyPhoenix.LiveView.Events`.
    """
    defmacro event(name) when is_binary(name) do
      module = used!(__CALLER__, "event/1")
      Module.put_attribute(module, :shoddy_phoenix_events, {name, __CALLER__.file, __CALLER__.line})

      case Module.get_attribute(module, :shoddy_phoenix_event_prefix) do
        nil -> name
        prefix -> prefix <> ":" <> name
      end
    end

    defmacro event(name) do
      raise ArgumentError,
            "event/1 needs a literal string, such as event(\"save\"). It received #{Macro.to_string(name)}."
    end

    @doc """
    Returns the prefix of the option `:prefix`.

    A widget gives the same name to
    `ShoddyPhoenix.LiveView.Widgets.route_events/3`, so the name occurs one
    time only:

    ```elixir
    use ShoddyPhoenix.LiveView.Events, prefix: "chat"

    def assign_widget(socket, key) do
      socket
      |> assign(key, %__MODULE__{key: key})
      |> Widgets.route_events(event_prefix(), &handle_event/3)
    end
    ```

    `event_prefix/0` is a macro. It raises `ArgumentError` at the compile
    time for a module without the option `:prefix`.
    """
    defmacro event_prefix do
      module = used!(__CALLER__, "event_prefix/0")

      case Module.get_attribute(module, :shoddy_phoenix_event_prefix) do
        nil ->
          raise ArgumentError,
                "event_prefix/0 needs the option :prefix, as in " <>
                  "`use ShoddyPhoenix.LiveView.Events, prefix: \"chat\"`."

        prefix ->
          prefix
      end
    end

    # Returns the module of the caller. Raises if that module does not use
    # this module.
    defp used!(caller, name) do
      module = caller.module

      if not Module.open?(module) or not Module.has_attribute?(module, :shoddy_phoenix_event_prefix) do
        raise ArgumentError, "#{name} needs `use ShoddyPhoenix.LiveView.Events` in the module that calls it."
      end

      module
    end

    defp prefix!(nil), do: nil

    defp prefix!(prefix) when is_binary(prefix) do
      if prefix == "" or String.contains?(prefix, ":") do
        raise ArgumentError,
              "the prefix of ShoddyPhoenix.LiveView.Events must be a string that is not empty " <>
                "and that contains no colon. It was #{inspect(prefix)}."
      end

      prefix
    end

    defp prefix!(prefix) do
      raise ArgumentError,
            "the prefix of ShoddyPhoenix.LiveView.Events must be a literal string. " <>
              "It was #{Macro.to_string(prefix)}."
    end

    @doc false
    @spec __after_compile__(Macro.Env.t(), binary()) :: :ok
    def __after_compile__(env, _bytecode) do
      module = env.module

      case handled(module) do
        :any ->
          :ok

        {names, prefixes} ->
          for {name, file, line} <- Enum.reverse(Module.get_attribute(module, :shoddy_phoenix_events)),
              name not in names,
              not Enum.any?(prefixes, &String.starts_with?(name, &1)) do
            IO.warn(
              "#{inspect(module)} has no clause of handle_event/3 for the event #{inspect(name)}",
              file: file,
              line: line
            )
          end

          :ok
      end
    end

    # Returns :any if a clause can handle each name. Otherwise returns the
    # literal names and the prefixes of the clauses.
    defp handled(module) do
      case Module.get_definition(module, {:handle_event, 3}) do
        nil ->
          {[], []}

        {:v1, _kind, _meta, clauses} ->
          clauses
          |> Enum.map(fn {_meta, [first | _rest], _guards, _body} -> pattern(first) end)
          |> Enum.reduce_while({[], []}, fn
            :any, _acc -> {:halt, :any}
            {:name, name}, {names, prefixes} -> {:cont, {[name | names], prefixes}}
            {:prefix, prefix}, {names, prefixes} -> {:cont, {names, [prefix | prefixes]}}
          end)
      end
    end

    # The definition has the expanded form of each head. The expanded form of
    # "chat:" <> rest is <<"chat:"::binary, rest::binary>>.
    defp pattern(name) when is_binary(name), do: {:name, name}

    defp pattern({:<<>>, _meta, segments}) do
      {literals, rest} = Enum.split_while(segments, &literal?/1)
      text = Enum.map_join(literals, &literal/1)
      if rest == [], do: {:name, text}, else: {:prefix, text}
    end

    defp pattern({:=, _meta, [left, right]}) do
      case {pattern(left), pattern(right)} do
        {:any, other} -> other
        {found, _other} -> found
      end
    end

    defp pattern(_other), do: :any

    defp literal?(segment), do: is_binary(literal(segment))

    defp literal({:"::", _meta, [text, {:binary, _spec_meta, _context}]}) when is_binary(text), do: text
    defp literal(_segment), do: nil
  end
end
