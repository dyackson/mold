defmodule PayloadValidator.AnySpec do
  use PayloadValidator.Spec, conform_fn_name: :any

  # no additional opts to check
  def check_spec(%__MODULE__{}), do: :ok

  # The PayloadValidator.Spec macro handles nil/nullable validation
  def conform(_, %__MODULE__{}), do: :ok
end
