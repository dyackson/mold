defmodule Dammit.Spec.Integer do
  use Dammit.Spec,
    fields: [:gt, :lt, :gte, :lte, :error_message, :get_error_message]
end

defimpl Dammit.ValidateSpec, for: Dammit.Spec.Integer do
  def validate_spec(params) do
    with :ok <- check_integer_or_nil(params, :lt),
         :ok <- check_integer_or_nil(params, :gt),
         :ok <- check_integer_or_nil(params, :lte),
         :ok <- check_integer_or_nil(params, :gte),
         :ok <- at_most_one(params, :lt, :lte),
         :ok <- at_most_one(params, :gt, :gte),
         :ok <- ensure_logical_bounds(params),
         {:ok, params} <- add_error_message(params) do
      {:ok, params}
    end
  end

  defp check_integer_or_nil(spec, bound) do
    case Map.get(spec, bound) do
      nil -> :ok
      it when is_integer(it) -> :ok
      _ -> {:error, "#{inspect(bound)} must be an integer"}
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
    # at this point, at_most_one/3 hessage ensured there is at most one lower or upper bound
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

      {{lower_k, lower_v}, {upper_k, upper_v}} when not (lower_v < upper_v) ->
        {:error, "#{inspect(lower_k)} must be less than #{inspect(upper_k)}"}

      _ ->
        :ok
    end
  end

  def get_error_message(%Dammit.Spec.Integer{} = params) do
    details =
      Enum.reduce(
        [
          gt: "greater than",
          gte: "greater than or equal to",
          lt: "less than",
          lte: "less than or equal to"
        ],
        [],
        fn {bound, desc}, details ->
          case Map.get(params, bound) do
            nil -> details
            int when is_integer(int) -> ["#{desc} #{int}" | details]
          end
        end
      )

    # add the details in the opposite order that they'll be displayed
    # so we can append to the front of the list and reverse at the end
    msg_start = "must be an integer"

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
end

defimpl Dammit.ValidateVal, for: Dammit.Spec.Integer do
  def validate_val(_spec, val) when not is_integer(val), do: {:error, "must be an integer"}

  def validate_val(%{lt: lt}, val) when not is_nil(lt) and not (val < lt),
    do: {:error, "must be less than #{lt}"}

  def validate_val(%{lte: lte}, val) when not is_nil(lte) and not (val <= lte),
    do: {:error, "must be less than or equal to #{lte}"}

  def validate_val(%{gt: gt}, val) when not is_nil(gt) and not (val > gt),
    do: {:error, "must be greater than #{gt}"}

  def validate_val(%{gte: gte}, val) when not is_nil(gte) and not (val >= gte),
    do: {:error, "must be greater than or equal to #{gte}"}

  def validate_val(_spec, _val), do: :ok
end
