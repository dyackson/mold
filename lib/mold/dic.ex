defmodule Mold.Dic do
  alias Mold.Common
  alias Mold.Error
  alias __MODULE__, as: Dic

  defstruct [
    :but,
    :error_message,
    :keys,
    :vals,
    :min,
    :max,
    nil_ok?: false,
    __prepped__: false
  ]

  defimpl Mold.Protocol do
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
           :ok <- Common.apply_but(mold, val) do
        :ok
      else
        :ok -> :ok
        :error -> {:error, mold.error_message}
        {:error, %{} = _nested_error_map} = it -> it
      end
    end

    defp local_prep!(%Dic{min: min, max: max} = mold) do
      prep_error_msg =
        cond do
          !Mold.Protocol.impl_for(mold.keys) || mold.keys.__struct__ not in [Mold.Str, Mold.Int] ->
            ":keys must be an %Mold.Str{} or %Mold.Int{}"

          !Mold.Protocol.impl_for(mold.vals) ->
            ":vals must implement the Mold protocol"

          not (is_nil(min) || (is_integer(min) and min >= 0)) ->
            ":min must be a non-negative integer"

          not (is_nil(max) || (is_integer(max) and max > 0)) ->
            ":max must be a positive integer"

          is_integer(min) && is_integer(max) && min > max ->
            ":min must be less than or equal to :max"

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
          case {mold.min, mold.max} do
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
         when is_integer(mold.min) and map_size(val) < mold.min,
         do: :error

    defp local_exam(%Dic{} = mold, val)
         when is_integer(mold.max) and map_size(val) > mold.max,
         do: :error

    defp local_exam(%Dic{} = mold, dic) do
      {nested_errors, bad_keys} =
        Enum.reduce(dic, {%{}, []}, fn
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

      # use a special field for bad keys because putting them in the error map the normal way is ambiguous
      error_map =
        case bad_keys do
          [_ | _] ->
            Map.put(nested_errors, :__key_errors__, %{
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
