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

    defp local_prep!(%Spec{min_size: min_size, max_size: max_size} = spec) do
      prep_error_msg =
        cond do
          !Anal.impl_for(spec.keys) || spec.keys.__struct__ not in [Anal.Str, Anal.Int, Anal.Dec] ->
            ":keys must be an %Anal.Str{}, %Anal.Int{}, or %Anal.Dec{}"

          !Anal.impl_for(spec.vals) ->
            ":vals must implement the Anal protocol"

          not (is_nil(min_size) || (is_integer(min_size) and min_size >= 0)) ->
            ":min_size must be a non-negative integer"

          not (is_nil(max_size) || (is_integer(max_size) and max_size > 0)) ->
            ":max_size must be a positive integer"

          is_integer(min_size) && is_integer(max_size) && min_size > max_size ->
            ":min_size must be less than or equal to :max_size"

          true ->
            nil
        end

      if is_binary(prep_error_msg), do: raise(SpecError.new(prep_error_msg))

      spec =
        spec
        |> Map.update!(:keys, &Anal.prep!/1)
        |> Map.update!(:vals, &Anal.prep!/1)

      if is_binary(spec.error_message) do
        # user-supplied error message exists, use nothing to do
        spec
      else
        key_val_msg =
          "where each key " <>
            spec.keys.error_message <> ", and each value " <> spec.vals.error_message

        error_message =
          case {spec.min_size, spec.max_size} do
            {nil, nil} ->
              "must be a mapping " <> key_val_msg

            {nil, max} ->
              "must be a mapping with at most #{max} entries, " <> key_val_msg

            {min, nil} ->
              "must be a mapping with at least #{min} entries, " <> key_val_msg

            {min, max} ->
              "must be a mapping with at least #{min} and at most #{max} entries, " <> key_val_msg
          end

        Map.put(spec, :error_message, error_message)
      end
    end

    defp local_exam(%Spec{}, val) when not is_map(val), do: :error

    defp local_exam(%Spec{} = spec, val)
         when is_integer(spec.min_size) and map_size(val) < spec.min_size,
         do: :error

    defp local_exam(%Spec{} = spec, val)
         when is_integer(spec.max_size) and map_size(val) > spec.max_size,
         do: :error

    defp local_exam(%Spec{} = spec, val) do
      {nested_errors, bad_keys} =
        Enum.reduce(val, {%{}, []}, fn
          {key, val}, {nested_errors, bad_keys} = _acc ->
            bad_keys =
              case Anal.exam(spec.keys, key) do
                {:error, _msg} -> [key | bad_keys]
                :ok -> bad_keys
              end

            nested_errors =
              case Anal.exam(spec.vals, val) do
                {:error, error} -> Map.put(nested_errors, key, error)
                :ok -> nested_errors
              end

            {nested_errors, bad_keys}
        end)

      # use a special field for bad keys because putting them in the error map the normal way is ambiguous
      error_map =
        case bad_keys do
          [_ | _] ->
            Map.put(nested_errors, "__key_errors__", %{
              keys: Enum.sort(bad_keys),
              message: spec.keys.error_message
            })

          [] ->
            nested_errors
        end

      if map_size(error_map) > 0, do: {:error, error_map}, else: :ok
    end
  end
end
