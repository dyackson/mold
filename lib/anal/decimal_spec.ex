defmodule Anal.DecimalSpec do
  alias Anal.Common
  alias __MODULE__, as: Spec

  defstruct [
    :gt,
    :lt,
    :gte,
    :lte,
    :max_decimal_places,
    :also,
    :get_error_message,
    :__error_message__,
    nil_ok?: false,
    __prepped__: false
  ]

  defimpl Anal.SpecProtocol do
    # not using Decimal lib to decide what's a decimal because it allows integers and scientific notation strings
    @decimal_regex ~r/^\s*-?\d*\.?\d+\s*$/
    @bad_bounds_spec_error_msg "must be a Decimal, a decimal-formatted string, or an integer"

    def prep!(%Spec{} = spec) do
      spec
      |> Common.prep!()
      |> check_max_decimal_places!()
      |> parse_decimal_or_nil!(lt: spec.lt)
      |> parse_decimal_or_nil!(gt: spec.gt)
      |> parse_decimal_or_nil!(lte: spec.lte)
      |> parse_decimal_or_nil!(gte: spec.gte)
      |> at_most_one!(lt: spec.lt, lte: spec.lte)
      |> at_most_one!(gt: spec.gt, gte: spec.gte)
      |> ensure_logical_bounds!()
      |> add_error_message()
      |> Map.put(:__prepped__, true)
    end

    def check_max_decimal_places!(%Spec{max_decimal_places: max_decimal_places})
        when not is_nil(max_decimal_places) and
               (not is_integer(max_decimal_places) or max_decimal_places < 1) do
      raise Anal.SpecError.new(":max_decimal_places must be a positive integer")
    end

    def check_max_decimal_places!(%Spec{} = spec), do: spec

    def validate_val(
          %{
            lt: lt,
            gt: gt,
            lte: lte,
            gte: gte,
            max_decimal_places: max_decimal_places
          },
          val
        ) do
      with true <- is_decimal_string?(val),
           true <- lt == nil or Decimal.lt?(val, lt),
           true <- lte == nil or not Decimal.gt?(val, lte),
           true <- gt == nil or Decimal.gt?(val, gt),
           true <- gte == nil or not Decimal.lt?(val, gte),
           true <- valid_decimal_places(val, max_decimal_places) do
        :ok
      else
        _ -> :error
      end
    end

    defp valid_decimal_places(val, max_decimal_places) do
      case String.split(val, ".") do
        [_] -> true
        [_, after_dot] -> String.length(after_dot) <= max_decimal_places
      end
    end

    defp at_most_one!(%Spec{} = spec, [{key1, val1}, {key2, val2}]) do
      if is_nil(val1) || is_nil(val2) do
        spec
      else
        raise Anal.SpecError.new("cannot use both #{inspect(key1)} and #{inspect(key2)}")
      end
    end

    defp ensure_logical_bounds!(%Spec{} = spec) do
      # at this point, at_most_one/3 has ensured there is at most one lower or upper bound
      lower_bound_tuple =
        case {Map.get(spec, :gt), Map.get(spec, :gte)} do
          {nil, nil} -> nil
          {gt, nil} -> {:gt, gt}
          {nil, gte} -> {:gte, gte}
        end

      upper_bound_tuple =
        case {Map.get(spec, :lt), Map.get(spec, :lte)} do
          {nil, nil} -> nil
          {lt, nil} -> {:lt, lt}
          {nil, lte} -> {:lte, lte}
        end

      case {lower_bound_tuple, upper_bound_tuple} do
        {l, u} when is_nil(l) or is_nil(u) ->
          :ok

        {{lower_k, lower_v}, {upper_k, upper_v}} ->
          if Decimal.lt?(lower_v, upper_v) do
            spec
          else
            raise Anal.SpecError.new("#{inspect(lower_k)} must be less than #{inspect(upper_k)}")
          end
      end
    end

    def add_error_message(%Anal.DecimalSpec{__error_message__: nil} = spec) do
      # add the details in the opposite order that they'll be displayed so we can append to the front of the list and reverse at the end.
      details =
        case spec.max_decimal_places do
          nil -> []
          num -> ["with up to #{num} decimal places"]
        end

      details =
        [
          {spec.gt, "greater than"},
          {spec.gte, "greater than or equal to"},
          {spec.lt, "less than"},
          {spec.lte, "less than or equal to"}
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
          [d1, d2] -> " " <> d1 <> ", " <> d2
          [d1, d2, d3] -> " " <> d1 <> ", " <> d2 <> ", " <> d3
        end

      preamble = if spec.nil_ok?, do: "if not nil, ", else: ""

      Map.put(
        spec,
        :__error_message__,
        preamble <> "must be a decial-formatted string" <> details
      )
    end

    def add_error_message(%Anal.DecimalSpec{} = spec), do: spec

    defp parse_decimal_or_nil!(%Spec{} = spec, [{key, val}]) do
      spec_or_error =
        case val do
          nil ->
            spec

          %Decimal{} ->
            spec

          int when is_integer(int) ->
            Map.put(spec, key, Decimal.new(int))

          str when is_binary(str) ->
            if is_decimal_string?(str) do
              Map.put(spec, key, Decimal.new(str))
            else
              :error
            end

          _ ->
            :error
        end

      case spec_or_error do
        :error -> raise Anal.SpecError.new("#{inspect(key)} #{@bad_bounds_spec_error_msg}")
        spec -> spec
      end
    end

    def is_decimal_string?(it) when is_binary(it) do
      Regex.match?(@decimal_regex, it)
    end

    def is_decimal_string?(_), do: false
  end
end