defmodule Mold.Rec do
  alias Mold.Common
  alias Mold.Error
  alias __MODULE__, as: Spec

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
    @spec_map_msg "must be a Map with string keys and Mold protocol-implementing values"

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
        case spec do
          %{exclusive?: ex} when not is_boolean(ex) ->
            ":exclusive? must be a boolean"

          %{exclusive?: true, required: r, optional: o} when r == %{} and o == %{} ->
            ":required and/or :optional must be used if :exclusive? is true"

          %{optional: o} when not is_map(o) ->
            ":optional " <> @spec_map_msg

          %{required: r} when not is_map(r) ->
            ":required " <> @spec_map_msg

          _ ->
            nil
        end

      if is_binary(prep_error_msg) do
        raise Error.new(prep_error_msg)
      else
        # recursively prep the nested fields on the spec
        prepped_required =
          Map.new(spec.required, fn {key, val} ->
            if not (is_binary(key) and is_spec?(val)),
              do: raise(Error.new(":required " <> @spec_map_msg))

            {key, Mold.prep!(val)}
          end)

        prepped_optional =
          Map.new(spec.optional, fn {key, val} ->
            if not (is_binary(key) and is_spec?(val)),
              do: raise(Error.new(":optional " <> @spec_map_msg))

            {key, Mold.prep!(val)}
          end)

        spec = Map.merge(spec, %{required: prepped_required, optional: prepped_optional})

        # check for duplicates in required and optional fields, not allowed
        optional_keys = spec.optional |> Map.keys() |> MapSet.new()
        required_keys = spec.required |> Map.keys() |> MapSet.new()

        shared_keys =
          MapSet.intersection(optional_keys, required_keys) |> MapSet.to_list() |> Enum.join(", ")

        if shared_keys != "" do
          raise(
            Error.new("the following keys were in both :optional and :required -- #{shared_keys}")
          )
        end

        # add the error message to the spec
        if is_binary(spec.error_message) do
          # user-supplied error message exists, use nothing to do
          spec
        else
          # tell them it must be a map with such and such keys
          required_key_str =
            spec.required
            |> Map.keys()
            |> Enum.sort()
            |> Enum.map(&~s["#{&1}"])
            |> Enum.join(", ")

          optional_key_str =
            spec.optional
            |> Map.keys()
            |> Enum.sort()
            |> Enum.map(&~s["#{&1}"])
            |> Enum.join(", ")

          error_message =
            case {spec.exclusive?, required_key_str, optional_key_str} do
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

          Map.put(spec, :error_message, error_message)
        end
      end
    end

    defp local_exam(%Spec{}, val) when not is_map(val), do: :error

    defp local_exam(%Spec{} = spec, %{}) when spec.required == %{} and spec.optional == %{},
      do: :ok

    defp local_exam(%Spec{} = spec, rec = %{}) do
      required = spec.required |> Map.keys() |> MapSet.new()
      actual = rec |> Map.keys() |> MapSet.new()

      missing = MapSet.difference(required, actual) |> Map.new(&{&1, "is required"})

      not_allowed =
        if spec.exclusive? do
          optional = spec.optional |> Map.keys() |> MapSet.new()
          allowed = MapSet.intersection(required, optional)
          MapSet.difference(actual, allowed) |> Map.new(&{&1, "is not allowed"})
        else
          %{}
        end

      errors_so_far = Map.merge(missing, not_allowed)

      errors_by_field =
        Enum.reduce(rec, errors_so_far, fn {key, val}, acc ->
          spec = Map.get(spec.required, key) || Map.get(spec.optional, key)
          missing? = Map.has_key?(missing, key)

          # recurse if the field is spec'd and present
          result = if spec == nil or missing?, do: :ok, else: Mold.exam(spec, val)

          case result do
            :ok ->
              acc

            {:error, error} when is_binary(error) or is_map(error) ->
              Map.put(acc, key, error)
          end
        end)

      if errors_by_field == %{}, do: :ok, else: {:error, errors_by_field}
    end

    def is_spec?(val), do: Mold.impl_for(val) != nil
  end
end
