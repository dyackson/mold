defmodule PayloadValidator.IntegerSpec do
  use PayloadValidator.Spec,
    conform_fn_name: :integer

  # no additional opts to check
  def check_spec(%__MODULE__{}), do: :ok

  def conform(val, %__MODULE__{}) when not is_integer(val), do: {:error, "must be an integer"}
  def conform(_, %__MODULE__{}), do: :ok
end
