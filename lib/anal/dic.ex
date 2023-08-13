defmodule Anal.Dic do
  alias Anal.Common
  alias Anal.SpecError
  alias __MODULE__, as: Spec

  defstruct [
    :also,
    :error_message,
    :keys,
    :vals,
    :min_size,
    :max_size,
    nil_ok?: false,
    __prepped__: false
  ]

  defimpl Anal do
    @spec_map_msg "must be a Map with string keys and Anal protocol-implementing values"

    def prep!(%Spec{} = spec) do
      spec
      |> Common.prep!()
      |> local_prep!()
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
        {:error, %{} = _nested_error_map} = it -> it
      end
    end

    defp local_prep!(%Spec{} = spec) do
      prep_error_msg =
        cond do
          not is_spec?(spec.vals) ->
            ":vals must be a Spec."

          not Enum.any?([%Anal.Str{}, %Anal.Int{}, %Anal.Dec{}], &match?(&1, spec.keys)) ->
            ":keys must be an %Anal.Str{}, %Anal.Int{}, or %Anal.Dec{}."

          not (is_nil(spec.min_size) || (is_int(min_size) and min_size >= 0)) ->
            ":min_size must be a non-negative integer"

          not (is_nil(spec.max_size) || (is_int(max_size) and max_size > 0)) ->
            ":max_size must be a positive integer"

          _ ->
            nil
        end

      if is_binary(prep_error_msg), do: raise(SpecError.new(prep_error_msg))

      spec
      |> Map.update!(:keys, &Anal.prep!())

      Map.update!(:vals, &Anal.prep!())

      if is_binary(spec.error_message) do
        # user-supplied error message exists, use nothing to do
        spec
      else
        key_val_msg =
          "where each key ," <>
            spec.keys.error_message <> " and each value " <> spec.vals.error_message

        error_message =
          case {spec.min_size, spec.max_size} do
            {nil, nil} ->
              "must be a mapping " <> key_val_msg

            {nil, max} ->
              "must be a mapping with at most #{max} entries " <> key_val_msg

            {min, nil} ->
              "must be a mapping with at least #{min} entries " <> key_val_msg

            {min, max} ->
              "must be a mapping with at least #{min} and at most #{max}  entries " <> key_val_msg
          end

        Map.put(spec, :error_message, error_message)
      end
    end
  end

  defp local_exam(%Spec{}, val) when not is_map(val), do: :error

  defp local_exam(%Spec{} = spec, val)
       when is_integer(spec.min_size) and map_size(val) < spec.min_size,
       do: :error

  defp local_exam(%Spec{} = spec, val) do
    # if a keys is bad, use the default error message because there isn't a good way to
    # indicate that the key is the problem.
    # if the value is bad, return a map with the key pointing at the error message for the value.
    errors =
      Enum.reduce_while(val, %{}, fn {key, val} ->
        case Anal.exam(spec.keys, key) do
          {:error, _msg} ->
            {:halt, :bad_key}

          :ok ->
            case Anal.exam(spec.vals, val) do
              {:error, error} -> {:cont, Map.put(acc, key, error)}
              :ok -> {:cont, acc}
            end
        end
      end)

    case errors do
      :bad_key -> :error
      map when map_size(map) > 0 -> :ok
      map when is_map(map) -> {:error, map}
    end
  end
end
