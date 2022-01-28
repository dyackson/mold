defmodule PayloadValidator.SpecBehavior do
  @type error_map() :: %{required(list()) => String.t()}
  @type spec() :: struct()

  @callback check_spec(spec()) :: :ok | {:error, String.t()}
  # Ideally there would be a way to specify term() is not nil because
  # The PaloadValidator Spec macro defines the callbacks for nil values.
  @callback conform(term(), spec()) :: :ok | {:error, String.t()} | {:error, error_map()}
end
