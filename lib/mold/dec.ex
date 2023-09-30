defmodule Mold.Dec do
  alias Mold.Common
  alias Mold.Error
  alias __MODULE__, as: Dec

  defstruct [
    :gt,
    :lt,
    :gte,
    :lte,
    :max_decimal_places,
    :but,
    :error_message,
    nil_ok?: false,
    __prepped__: false
  ]

  defimpl Mold.Protocol do
    # not using Decimal lib to decide what's a decimal because it allows integers and scientific notation strings
    @decimal_regex ~r/^\s*-?\d*\.?\d+\s*$/

    def prep!(%Dec{} = mold) do
      mold
      |> Common.prep!()
      |> check_max_decimal_places!()
      |> parse_decimal_or_nil!(lt: mold.lt)
      |> parse_decimal_or_nil!(gt: mold.gt)
      |> parse_decimal_or_nil!(lte: mold.lte)
      |> parse_decimal_or_nil!(gte: mold.gte)
      |> at_most_one!(lt: mold.lt, lte: mold.lte)
      |> at_most_one!(gt: mold.gt, gte: mold.gte)
      |> ensure_logical_bounds!()
      |> add_error_message()
      |> Map.put(:__prepped__, true)
    end

    def exam(%Dec{} = mold, val) do
      mold = Common.check_prepped!(mold)

      with :not_nil <- Common.exam_nil(mold, val),
           :ok <- local_exam(mold, val),
           :ok <- Common.apply_but(mold, val) do
        :ok
      else
        :ok -> :ok
        :error -> {:error, mold.error_message}
      end
    end

    defp local_exam(%Dec{} = mold, val) do
      with true <- is_decimal_string?(val),
           true <- mold.lt == nil or Decimal.lt?(val, mold.lt),
           true <- mold.lte == nil or not Decimal.gt?(val, mold.lte),
           true <- mold.gt == nil or Decimal.gt?(val, mold.gt),
           true <- mold.gte == nil or not Decimal.lt?(val, mold.gte),
           true <- valid_decimal_places?(val, mold.max_decimal_places) do
        :ok
      else
        _ -> :error
      end
    end

    defp check_max_decimal_places!(%Dec{max_decimal_places: max_decimal_places})
         when not is_nil(max_decimal_places) and
                (not is_integer(max_decimal_places) or max_decimal_places < 0) do
      raise Error.new(":max_decimal_places must be a non-negative integer")
    end

    defp check_max_decimal_places!(%Dec{} = mold), do: mold

    defp valid_decimal_places?(val, max_decimal_places) do
      case String.split(val, ".") do
        [_] -> true
        [_, after_dot] -> String.length(after_dot) <= max_decimal_places
      end
    end

    defp at_most_one!(%Dec{} = mold, [{key1, val1}, {key2, val2}]) do
      if is_nil(val1) || is_nil(val2) do
        mold
      else
        raise Error.new("cannot use both #{inspect(key1)} and #{inspect(key2)}")
      end
    end

    defp ensure_logical_bounds!(%Dec{} = mold) do
      # at this point, at_most_one/3 has ensured there is at most one lower or upper bound
      lower_bound_tuple =
        case {mold.gt, mold.gte} do
          {nil, nil} -> nil
          {gt, nil} -> {:gt, gt}
          {nil, gte} -> {:gte, gte}
        end

      upper_bound_tuple =
        case {mold.lt, mold.lte} do
          {nil, nil} -> nil
          {lt, nil} -> {:lt, lt}
          {nil, lte} -> {:lte, lte}
        end

      case {lower_bound_tuple, upper_bound_tuple} do
        {l, u} when is_nil(l) or is_nil(u) ->
          mold

        {{lower_k, lower_v}, {upper_k, upper_v}} ->
          if Decimal.lt?(lower_v, upper_v) do
            mold
          else
            raise Error.new("#{inspect(lower_k)} must be less than #{inspect(upper_k)}")
          end
      end
    end

    def add_error_message(%Dec{error_message: nil} = mold) do
      # add the details in the opposite order that they'll be displayed so we can append to the front of the list and reverse at the end.
      details =
        case mold.max_decimal_places do
          nil -> []
          num -> ["with up to #{num} decimal places"]
        end

      details =
        [
          {mold.gt, "greater than"},
          {mold.gte, "greater than or equal to"},
          {mold.lt, "less than"},
          {mold.lte, "less than or equal to"}
        ]
        |> Enum.reject(fn {val, _} -> val == nil end)
        |> Enum.reduce(details, fn {val, desc}, acc ->
          case val do
            nil -> acc
            _ -> ["#{desc} #{Decimal.to_string(val, :normal)}" | acc]
          end
        end)

      details =
        case Enum.reverse(details) do
          [] -> ""
          [d1] -> " " <> d1
          [d1, d2] -> " " <> d1 <> " and " <> d2
          [d1, d2, d3] -> " " <> d1 <> ", " <> d2 <> ", and " <> d3
        end

      preamble = if mold.nil_ok?, do: "if not nil, ", else: ""

      Map.put(
        mold,
        :error_message,
        preamble <> "must be a decimal-formatted string" <> details
      )
    end

    def add_error_message(%Dec{} = mold), do: mold

    defp parse_decimal_or_nil!(%Dec{} = mold, [{key, val}]) do
      mold_or_error =
        case val do
          nil ->
            mold

          %Decimal{} ->
            mold

          int when is_integer(int) ->
            Map.put(mold, key, Decimal.new(int))

          str when is_binary(str) ->
            if is_decimal_string?(str) do
              Map.put(mold, key, Decimal.new(str))
            else
              :error
            end

          _ ->
            :error
        end

      case mold_or_error do
        :error ->
          raise Error.new(
                  "#{inspect(key)} must be a Decimal, a decimal-formatted string, or an integer"
                )

        mold ->
          mold
      end
    end

    def is_decimal_string?(it) when is_binary(it) do
      Regex.match?(@decimal_regex, it)
    end

    def is_decimal_string?(_), do: false
  end
end
