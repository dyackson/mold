defmodule Anal.BooleanSpec do
  use Anal.Spec
end

defimpl Anal.SpecProtocol, for: Anal.BooleanSpec do
  def validate_spec(_spec), do: :ok
  def validate_val(_spec, val) when is_boolean(val), do: :ok
  def validate_val(_spec, _val), do: {:error, "must be a boolean"}
end
