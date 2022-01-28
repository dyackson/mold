defmodule PayloadValidator.BooleanSpec do
  use PayloadValidator.Spec, conform_fn_name: :boolean

  # no additional opts to check
  def check_spec(%__MODULE__{}), do: :ok

  def conform(val, %__MODULE__{}) when not is_boolean(val), do: {:error, "must be a boolean"}
  def conform(_, %__MODULE__{}), do: :ok
end
