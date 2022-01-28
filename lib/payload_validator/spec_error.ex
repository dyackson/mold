defmodule PayloadValidator.SpecError do
  defexception [:message]

  def new(message), do: %__MODULE__{message: message}
end
