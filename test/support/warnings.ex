defmodule ShoddyPhoenix.Test.Warnings do
  @moduledoc false
  # A test that compiles code reads the warnings of the compiler with this
  # module. ExUnit.CaptureIO captures the standard error of all processes, so
  # two async tests can capture the warnings of each other.
  # Code.with_diagnostics/2 collects only the warnings of its own process.

  @doc false
  # Runs the function, and returns each warning and each error as one line.
  # The line contains the name of the file, the line number and the message.
  def collect(fun) do
    {_result, diagnostics} = Code.with_diagnostics([log: false], fun)

    Enum.map_join(diagnostics, fn %{file: file, position: position, message: message} ->
      "#{file && Path.basename(file)}:#{line(position)}: #{message}\n"
    end)
  end

  defp line({line, _column}), do: line
  defp line(line), do: line
end
