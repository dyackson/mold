defmodule Dammit.BooleanSpec do
  use Dammit.Spec
end

defimpl Dammit.SpecProtocol, for: Dammit.BooleanSpec do
  def validate_spec(_spec), do: :ok
  def validate_val(_spec, val) when is_boolean(val), do: :ok
  def validate_val(_spec, _val), do: {:error, "must be a boolean"}
end
