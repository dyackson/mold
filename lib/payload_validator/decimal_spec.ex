defmodule PayloadValidator.DecimalSpec do
  use PayloadValidator.Spec,
    conform_fn_name: :decimal

  # Uses a regex rather than Decimal.parse/1, to avoid excepting scientific notation.
  @decimal_regex ~r/^\s*\d*\.?\d+\s*$/
  @error_msg "must be a decimal-formatted string or an integer"

  # no additional opts to check
  def check_spec(%__MODULE__{}), do: :ok

  def conform(val, %__MODULE__{}) when is_integer(val), do: :ok

  def conform(val, %__MODULE__{}) when is_binary(val) do
    if Regex.match?(@decimal_regex, val) do
      :ok
    else
      {:error, @error_msg}
    end
  end

  def conform(_, %__MODULE__{}), do: {:error, @error_msg}
end
