defmodule Dammit.Spec.Decimal do
  @decimal_regex ~r/^\s*-?\d*\.?\d+\s*$/

  use Dammit.Spec,
    fields: [
      :gt,
      :lt,
      :gte,
      :lte,
      :max_decimal_places,
      :get_error_message,
      # TODO: do a check like for :required that tells them they can't supply this
      error_message: :internal
    ]

  def is_decimal_string(it) when is_binary(it) do
    Regex.match?(@decimal_regex, it)
  end

  def is_decimal_string(_), do: false

  def decimal_regex, do: @decimal_regex
end

defimpl Dammit.ValidateSpec, for: Dammit.Spec.Decimal do
  @bad_bounds_spec_error_msg "must be a Decimal, a decimal-formatted string, or an integer"

  def validate_spec(%{max_decimal_places: max_decimal_places})
      when not is_nil(max_decimal_places) and
             (not is_integer(max_decimal_places) or max_decimal_places < 1) do
    {:error, ":max_decimal_places must be a positive integer"}
  end

  def validate_spec(params) do
    with {:ok, params} <- parse_decimal_or_nil(params, :lt),
         {:ok, params} <- parse_decimal_or_nil(params, :gt),
         {:ok, params} <- parse_decimal_or_nil(params, :lte),
         {:ok, params} <- parse_decimal_or_nil(params, :gte),
         :ok <- at_most_one(params, :lt, :lte),
         :ok <- at_most_one(params, :gt, :gte),
         :ok <- ensure_logical_bounds(params),
         {:ok, params} <- add_error_message(params) do
      {:ok, params}
    end
  end

  defp at_most_one(params, bound1, bound2) do
    b1 = Map.get(params, bound1)
    b2 = Map.get(params, bound2)

    if is_nil(b1) || is_nil(b2) do
      :ok
    else
      {:error, "cannot use both #{inspect(bound1)} and #{inspect(bound2)}"}
    end
  end

  defp ensure_logical_bounds(params) do
    # at this point, at_most_one/3 hessage ensured there is at most one lower orupper:  bound
    lower_bound_tuple =
      case {Map.get(params, :gt), Map.get(params, :gte)} do
        {nil, nil} -> nil
        {gt, nil} -> {:gt, gt}
        {nil, gte} -> {:gte, gte}
      end

    upper_bound_tuple =
      case {Map.get(params, :lt), Map.get(params, :lte)} do
        {nil, nil} -> nil
        {lt, nil} -> {:lt, lt}
        {nil, lte} -> {:lte, lte}
      end

    case {lower_bound_tuple, upper_bound_tuple} do
      {l, u} when is_nil(l) or is_nil(u) ->
        :ok

      {{lower_k, lower_v}, {upper_k, upper_v}} ->
        if Decimal.lt?(lower_v, upper_v) do
          :ok
        else
          {:error, "#{inspect(lower_k)} must be less than #{inspect(upper_k)}"}
        end
    end
  end

  def get_error_message(%Dammit.Spec.Decimal{} = params) do
    # add the details in the opposite order that they'll be displayed so we can append to the front of the list and reverse at the end.
    details =
      case params.max_decimal_places do
        nil -> []
        num -> ["with up to #{num} decimal places"]
      end

    details =
      Enum.reduce(
        [
          gt: "greater than",
          gte: "greater than or equal to",
          lt: "less than",
          lte: "less than or equal to"
        ],
        details,
        fn {bound, desc}, details ->
          case Map.get(params, bound) do
            nil -> details
            decimal -> ["#{desc} #{Decimal.to_string(decimal, :normal)}" | details]
          end
        end
      )

    msg_start = "must be a decimal-formatted string"

    case Enum.reverse(details) do
      [] -> msg_start
      [d1] -> msg_start <> " " <> d1
      [d1, d2] -> msg_start <> " " <> d1 <> " and " <> d2
      [d1, d2, d3] -> msg_start <> " " <> d1 <> ", " <> d2 <> ", and " <> d3
    end
  end

  def add_error_message(params) do
    error_message =
      if is_function(params.get_error_message, 1) do
        params.get_error_message.(params)
      else
        get_error_message(params)
      end

    {:ok, Map.put(params, :error_message, error_message)}
  end

  defp parse_decimal_or_nil(params, bound) do
    val = params |> Map.from_struct() |> Map.get(bound)

    case val do
      nil ->
        {:ok, params}

      %Decimal{} ->
        {:ok, params}

      int when is_integer(int) ->
        {:ok, Map.put(params, bound, Decimal.new(val))}

      str when is_binary(str) ->
        if Regex.match?(Dammit.Spec.Decimal.decimal_regex(), str) do
          {:ok, Map.put(params, bound, Decimal.new(val))}
        else
          {:error, "#{inspect(bound)} #{@bad_bounds_spec_error_msg}"}
        end

      _ ->
        {:error, "#{inspect(bound)} #{@bad_bounds_spec_error_msg}"}
    end
  end
end

defimpl Dammit.ValidateVal, for: Dammit.Spec.Decimal do
  def validate_val(
        %{
          lt: lt,
          gt: gt,
          lte: lte,
          gte: gte,
          max_decimal_places: max_decimal_places,
          error_message: error_message
        },
        val
      ) do
    with true <-
           Dammit.Spec.Decimal.is_decimal_string(val),
         true <- lt == nil or Decimal.lt?(val, lt),
         true <- lte == nil or not Decimal.gt?(val, lte),
         true <- gt == nil or Decimal.gt?(val, gt),
         true <- gte == nil or not Decimal.lt?(val, gte),
         true <- valid_decimal_places(val, max_decimal_places) do
      :ok
    else
      _ -> {:error, error_message}
    end
  end

  defp valid_decimal_places(val, max_decimal_places) do
    case String.split(val, ".") do
      [_] -> true
      [_, after_dot] -> String.length(after_dot) <= max_decimal_places
    end
  end
end
