defmodule Mold.Rec do
  alias Mold.Common
  alias Mold.Error
  alias __MODULE__, as: Rec

  defstruct [
    :also,
    :error_message,
    required: %{},
    optional: %{},
    nil_ok?: false,
    exclusive?: false,
    __prepped__: false
  ]

  defimpl Mold do
    @mold_map_msg "must be a Map with string keys and Mold protocol-implementing values"

    def prep!(%Rec{} = mold) do
      mold
      |> Common.prep!()
      |> local_prep!()
      |> Map.put(:__prepped__, true)
    end

    def exam(%Rec{} = mold, val) do
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

    defp local_prep!(%Rec{} = mold) do
      prep_error_msg =
        case mold do
          %{exclusive?: ex} when not is_boolean(ex) ->
            ":exclusive? must be a boolean"

          %{exclusive?: true, required: r, optional: o} when r == %{} and o == %{} ->
            ":required and/or :optional must be used if :exclusive? is true"

          %{optional: o} when not is_map(o) ->
            ":optional " <> @mold_map_msg

          %{required: r} when not is_map(r) ->
            ":required " <> @mold_map_msg

          _ ->
            nil
        end

      if is_binary(prep_error_msg) do
        raise Error.new(prep_error_msg)
      else
        # recursively prep the nested fields on the mold
        prepped_required =
          Map.new(mold.required, fn {key, val} ->
            if not (is_binary(key) and is_mold?(val)),
              do: raise(Error.new(":required " <> @mold_map_msg))

            {key, Mold.prep!(val)}
          end)

        prepped_optional =
          Map.new(mold.optional, fn {key, val} ->
            if not (is_binary(key) and is_mold?(val)),
              do: raise(Error.new(":optional " <> @mold_map_msg))

            {key, Mold.prep!(val)}
          end)

        mold = Map.merge(mold, %{required: prepped_required, optional: prepped_optional})

        # check for duplicates in required and optional fields, not allowed
        optional_keys = mold.optional |> Map.keys() |> MapSet.new()
        required_keys = mold.required |> Map.keys() |> MapSet.new()

        shared_keys =
          MapSet.intersection(optional_keys, required_keys) |> MapSet.to_list() |> Enum.join(", ")

        if shared_keys != "" do
          raise(
            Error.new("the following keys were in both :optional and :required -- #{shared_keys}")
          )
        end

        # add the error message to the mold
        if is_binary(mold.error_message) do
          # user-supplied error message exists, use nothing to do
          mold
        else
          # tell them it must be a map with such and such keys
          required_key_str =
            mold.required
            |> Map.keys()
            |> Enum.sort()
            |> Enum.map(&~s["#{&1}"])
            |> Enum.join(", ")

          optional_key_str =
            mold.optional
            |> Map.keys()
            |> Enum.sort()
            |> Enum.map(&~s["#{&1}"])
            |> Enum.join(", ")

          error_message =
            case {mold.exclusive?, required_key_str, optional_key_str} do
              {false, "", ""} ->
                "must be a record"

              {false, "", o} ->
                "must be a record with the optional keys " <> o

              {false, r, ""} ->
                "must be a record with the required keys " <> r

              {false, r, o} ->
                "must be a record with the required keys " <> r <> " and the optional keys " <> o

              {true, "", ""} ->
                raise("bug, should have raised during local_prep")

              {true, "", o} ->
                "must be a record with only the optional keys " <> o

              {true, r, ""} ->
                "must be a record with only the required keys " <> r

              {true, r, o} ->
                "must be a record with only the required keys " <>
                  r <> " and the optional keys " <> o
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
    end

    defp local_exam(%Rec{}, val) when not is_map(val), do: :error

    defp local_exam(%Rec{} = mold, %{}) when mold.required == %{} and mold.optional == %{},
      do: :ok

    defp local_exam(%Rec{} = mold, rec = %{}) do
      required = mold.required |> Map.keys() |> MapSet.new()
      actual = rec |> Map.keys() |> MapSet.new()

      missing = MapSet.difference(required, actual) |> Map.new(&{&1, "is required"})

      not_allowed =
        if mold.exclusive? do
          optional = mold.optional |> Map.keys() |> MapSet.new()
          allowed = MapSet.intersection(required, optional)
          MapSet.difference(actual, allowed) |> Map.new(&{&1, "is not allowed"})
        else
          %{}
        end

      errors_so_far = Map.merge(missing, not_allowed)

      errors_by_field =
        Enum.reduce(rec, errors_so_far, fn {key, val}, acc ->
          mold = Map.get(mold.required, key) || Map.get(mold.optional, key)
          missing? = Map.has_key?(missing, key)

          # recurse if the field is mold'd and present
          result = if mold == nil or missing?, do: :ok, else: Mold.exam(mold, val)

          case result do
            :ok ->
              acc

            {:error, error} when is_binary(error) or is_map(error) ->
              Map.put(acc, key, error)
          end
        end)

      if errors_by_field == %{}, do: :ok, else: {:error, errors_by_field}
    end

    def is_mold?(val), do: Mold.impl_for(val) != nil
  end
end
