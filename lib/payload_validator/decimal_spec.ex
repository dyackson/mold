defmodule PayloadValidator.DecimalSpec do
  use PayloadValidator.Spec,
    conform_fn_name: :decimal,
    fields: [:gt, :lt, :gte, :lte, :max_decimal_places]

  # Uses a regex rather than Decimal.parse/1, to avoid excepting scientific notation.
  @decimal_regex ~r/^\s*\d*\.?\d+\s*$/
  @error_msg "must be a decimal-formatted string or an integer"

  def check_spec(%__MODULE__{max_decimal_places: max_decimal_places})
      when (not is_integer(max_decimal_places) and not is_nil(max_decimal_places)) or
             (is_integer(max_decimal_places) and max_decimal_places < 0) do
    {:error, "max_decimal_places must be a non-negative integer"}
  end

  def check_spec(%__MODULE__{gt: gt, gte: gte}) when not is_nil(gt) and not is_nil(gte) do
    {:error, "cannot specify both gt and gte"}
  end

  def check_spec(%__MODULE__{lt: lt, lte: lte}) when not is_nil(lt) and not is_nil(lte) do
    {:error, "cannot specify both lt and lte"}
  end

  def check_spec(%__MODULE__{} = spec) do
    with %__MODULE__{} = spec <- check_bound(spec, :gt, spec.gt),
         %__MODULE__{} = spec <- check_bound(spec, :gte, spec.gte),
         %__MODULE__{} = spec <- check_bound(spec, :lt, spec.lt),
         %__MODULE__{} = spec <- check_bound(spec, :lte, spec.lte) do
      case spec do
        %{gt: gt, lt: lt} when not is_nil(gt) and not is_nil(lt) ->
          if not Decimal.lt?(gt, lt),
            do: {:error, "gt must be less than lt"},
            else: {:ok, spec}

        %{gt: gt, lte: lte} when not is_nil(gt) and not is_nil(lte) ->
          if not Decimal.lt?(gt, lte),
            do: {:error, "gt must be less than lte"},
            else: {:ok, spec}

        %{gte: gte, lt: lt} when not is_nil(gte) and not is_nil(lt) ->
          if not Decimal.lt?(gte, lt),
            do: {:error, "gte must be less than lt"},
            else: {:ok, spec}

        %{gte: gte, lte: lte} when not is_nil(gte) and not is_nil(lte) ->
          if Decimal.gt?(gte, lte),
            do: {:error, "gte must be less than or equal to lte"},
            else: {:ok, spec}

        spec ->
          {:ok, spec}
      end
    end
  end

  defp check_bound(spec, comparison, bound) do
    case bound do
      nil ->
        spec

      %Decimal{} ->
        spec

      bound when is_integer(bound) ->
        Map.put(spec, comparison, Decimal.new(bound))

      bound when is_binary(bound) ->
        if Regex.match?(@decimal_regex, bound) do
          Map.put(spec, comparison, Decimal.new(bound))
        else
          {:error, bad_bound_msg(comparison)}
        end

      _ ->
        {:error, bad_bound_msg(comparison)}
    end
  end

  defp bad_bound_msg(comparison),
    do: "#{Atom.to_string(comparison)} must be an integer, decimal-formatted string, or Decimal"

  def conform(val, %__MODULE__{} = spec) when is_integer(val) do
    case conform_bounds(val, spec) do
      :ok -> :ok
      error_msg -> {:error, error_msg}
    end
  end

  def conform(val, %__MODULE__{} = spec) when is_binary(val) do
    with :ok <- conform_regex(val),
         :ok <- conform_max_decimal_places(val, spec.max_decimal_places),
         :ok <- conform_bounds(val, spec) do
      :ok
    else
      error_msg -> {:error, error_msg}
    end
  end

  def conform(_, %__MODULE__{}), do: {:error, @error_msg}

  defp conform_regex(val) do
    if Regex.match?(@decimal_regex, val) do
      :ok
    else
      @error_msg
    end
  end

  defp conform_max_decimal_places(_val, nil), do: :ok

  defp conform_max_decimal_places(val, max) do
    regex =
      case max do
        0 -> ~r/^\s*\d+\s*$/
        _ -> Regex.compile!("^\\s*\\d*\\.?\\d{1,#{max}}\\s*$")
      end

    if Regex.match?(regex, val) do
      :ok
    else
      "cannot have more than #{max} digits after the decimal point"
    end
  end

  defp conform_bounds(val, %__MODULE__{gt: gt, lt: lt, lte: lte, gte: gte}) do
    decimal_val = Decimal.new(val)

    with :ok <- conform_bound(decimal_val, :gt, gt),
         :ok <- conform_bound(decimal_val, :gte, gte),
         :ok <- conform_bound(decimal_val, :lt, lt),
         :ok <- conform_bound(decimal_val, :lte, lte) do
      :ok
    end
  end

  defp conform_bound(_decimal_val, _comparison, nil = _bound), do: :ok

  defp conform_bound(decimal_val, :gt, %Decimal{} = bound) do
    if Decimal.gt?(decimal_val, bound) do
      :ok
    else
      "must be greater than #{bound}"
    end
  end

  defp conform_bound(decimal_val, :gte, %Decimal{} = bound) do
    if not Decimal.lt?(decimal_val, bound) do
      :ok
    else
      "must be greater than or equal to #{bound}"
    end
  end

  defp conform_bound(decimal_val, :lt, %Decimal{} = bound) do
    if Decimal.lt?(decimal_val, bound) do
      :ok
    else
      "must be less than #{bound}"
    end
  end

  defp conform_bound(decimal_val, :lte, %Decimal{} = bound) do
    if not Decimal.gt?(decimal_val, bound) do
      :ok
    else
      "must be less than or equal to #{bound}"
    end
  end
end
