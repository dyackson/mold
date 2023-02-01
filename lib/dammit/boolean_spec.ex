defmodule Dammit.BooleanSpec do
  @derive [Dammit.ValidateSpec]
  use Dammit.Spec
end

defimpl Dammit.ValidateVal, for: Dammit.BooleanSpec do
  def validate_val(_spec, val) when is_boolean(val), do: :ok
  def validate_val(_spec, _val), do: {:error, "must be a boolean"}
end
