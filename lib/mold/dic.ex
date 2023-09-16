defmodule Mold.Dic do
  alias Mold.Common
  alias Mold.Error
  alias __MODULE__, as: Dic

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

  defimpl Mold do
    def prep!(%Dic{} = mold) do
      mold
      |> Common.prep!()
      |> local_prep!()
      |> Map.put(:__prepped__, true)
    end

    def exam(%Dic{} = mold, val) do
      mold = Common.check_prepped!(mold)

      with :not_nil <- Common.exam_nil(mold, val),
           :ok <- local_exam(mold, val),
           :ok <- Common.apply_also(mold, val) do
        :ok
      else
        :ok -> :ok
        :error -> {:error, mold.error_message}
        {:error, %{} = _nested_error_map} = it -> it
      end
    end

    defp local_prep!(%Dic{min_size: min_size, max_size: max_size} = mold) do
      prep_error_msg =
        cond do
          !Mold.impl_for(mold.keys) || mold.keys.__struct__ not in [Mold.Str, Mold.Int] ->
            ":keys must be an %Mold.Str{} or %Mold.Int{}"

          !Mold.impl_for(mold.vals) ->
            ":vals must implement the Mold protocol"

          not (is_nil(min_size) || (is_integer(min_size) and min_size >= 0)) ->
            ":min_size must be a non-negative integer"

          not (is_nil(max_size) || (is_integer(max_size) and max_size > 0)) ->
            ":max_size must be a positive integer"

          is_integer(min_size) && is_integer(max_size) && min_size > max_size ->
            ":min_size must be less than or equal to :max_size"

          true ->
            nil
        end

      if is_binary(prep_error_msg), do: raise(Error.new(prep_error_msg))

      mold =
        mold
        |> Map.update!(:keys, &Mold.prep!/1)
        |> Map.update!(:vals, &Mold.prep!/1)

      if is_binary(mold.error_message) do
        # user-supplied error message exists, use nothing to do
        mold
      else
        key_val_msg =
          "where each key " <>
            mold.keys.error_message <> ", and each value " <> mold.vals.error_message

        error_message =
          case {mold.min_size, mold.max_size} do
            {nil, nil} ->
              "must be a mapping " <> key_val_msg

            {nil, max} ->
              "must be a mapping with at most #{max} entries, " <> key_val_msg

            {min, nil} ->
              "must be a mapping with at least #{min} entries, " <> key_val_msg

            {min, max} ->
              "must be a mapping with at least #{min} and at most #{max} entries, " <> key_val_msg
          end

        error_message =
          if mold.nil_ok? do
            "if not nil, " <> error_message
          else
            error_message
          end

        Map.put(mold, :error_message, error_message)
      end
    end

    defp local_exam(%Dic{}, val) when not is_map(val), do: :error

    defp local_exam(%Dic{} = mold, val)
         when is_integer(mold.min_size) and map_size(val) < mold.min_size,
         do: :error

    defp local_exam(%Dic{} = mold, val)
         when is_integer(mold.max_size) and map_size(val) > mold.max_size,
         do: :error

    defp local_exam(%Dic{} = mold, val) do
      {nested_errors, bad_keys} =
        Enum.reduce(val, {%{}, []}, fn
          {key, val}, {nested_errors, bad_keys} = _acc ->
            bad_keys =
              case Mold.exam(mold.keys, key) do
                {:error, _msg} -> [key | bad_keys]
                :ok -> bad_keys
              end

            nested_errors =
              case Mold.exam(mold.vals, val) do
                {:error, error} -> Map.put(nested_errors, key, error)
                :ok -> nested_errors
              end

            {nested_errors, bad_keys}
        end)

      # use a moldial field for bad keys because putting them in the error map the normal way is ambiguous
      error_map =
        case bad_keys do
          [_ | _] ->
            Map.put(nested_errors, "__key_errors__", %{
              keys: Enum.sort(bad_keys),
              message: mold.keys.error_message
            })

          [] ->
            nested_errors
        end

      if map_size(error_map) > 0, do: {:error, error_map}, else: :ok
    end
  end
end
