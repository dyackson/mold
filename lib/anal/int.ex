defmodule Anal.Int do
  alias Anal.Common
  alias Anal.SpecError
  alias __MODULE__, as: Spec

  defstruct [
    :gt,
    :lt,
    :gte,
    :lte,
    :also,
    :error_message,
    nil_ok?: false,
    __prepped__: false
  ]

  defimpl Anal do
    def prep!(%Spec{} = spec) do
      spec
      |> Common.prep!()
      |> check_integer_or_nil!(lt: spec.lt)
      |> check_integer_or_nil!(gt: spec.gt)
      |> check_integer_or_nil!(lte: spec.lte)
      |> check_integer_or_nil!(gte: spec.gte)
      |> at_most_one!(lt: spec.lt, lte: spec.lte)
      |> at_most_one!(gt: spec.gt, gte: spec.gte)
      |> ensure_logical_bounds!()
      |> add_error_message()
      |> Map.put(:__prepped__, true)
    end

    def exam(%Spec{} = spec, val) do
      spec = Common.check_prepped!(spec)

      with :not_nil <- Common.exam_nil(spec, val),
           :ok <- local_exam(spec, val),
           :ok <- Common.apply_also(spec, val) do
        :ok
      else
        :ok -> :ok
        :error -> {:error, spec.error_message}
      end
    end

    defp local_exam(%Spec{} = spec, val) do
      with true <- is_integer(val),
           true <- spec.lt == nil or val < spec.lt,
           true <- spec.lte == nil or val <= spec.lte,
           true <- spec.gt == nil or val > spec.gt,
           true <- spec.gte == nil or val >= spec.gte do
        :ok
      else
        _ -> :error
      end
    end

    defp check_integer_or_nil!(%Spec{} = spec, [{_key, val}]) when is_integer(val) or is_nil(val),
      do: spec

    defp check_integer_or_nil!(%Spec{}, [{key, _val}]),
      do: raise(SpecError.new("#{inspect(key)} must be an integer"))

    defp at_most_one!(%Spec{} = spec, [{key1, val1}, {key2, val2}]) do
      if is_nil(val1) || is_nil(val2) do
        spec
      else
        raise SpecError.new("cannot use both #{inspect(key1)} and #{inspect(key2)}")
      end
    end

    defp ensure_logical_bounds!(%Spec{} = spec) do
      # at this point, at_most_one/3 hessage ensured there is at most one lower or upper bound
      lower_bound_tuple =
        case {spec.gt, spec.gte} do
          {nil, nil} -> nil
          {gt, nil} -> {:gt, gt}
          {nil, gte} -> {:gte, gte}
        end

      upper_bound_tuple =
        case {spec.lt, spec.lte} do
          {nil, nil} -> nil
          {lt, nil} -> {:lt, lt}
          {nil, lte} -> {:lte, lte}
        end

      case {lower_bound_tuple, upper_bound_tuple} do
        {l, u} when is_nil(l) or is_nil(u) ->
          spec

        {{lower_k, lower_v}, {upper_k, upper_v}} ->
          if lower_v < upper_v do
            spec
          else
            raise SpecError.new("#{inspect(lower_k)} must be less than #{inspect(upper_k)}")
          end
      end
    end

    def add_error_message(%Anal.Int{error_message: nil} = spec) do
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
            case Map.get(spec, bound) do
              nil -> details
              int when is_integer(int) -> ["#{desc} #{int}" | details]
            end
          end
        )

      # add the details in the opposite order that they'll be displayed
      # so we can append to the front of the list and reverse at the end
      details =
        case Enum.reverse(details) do
          [] -> ""
          [d1] -> " " <> d1
          [d1, d2] -> " " <> d1 <> " and " <> d2
        end

      preamble = if spec.nil_ok?, do: "if not nil, ", else: ""

      Map.put(
        spec,
        :error_message,
        preamble <> "must be an integer" <> details
      )
    end

    def add_error_message(%Anal.Int{} = spec), do: spec
  end
end
