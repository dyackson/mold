defmodule Anal.Rec do
  alias Anal.Common
  alias Anal.SpecError
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

  defimpl Anal do
    @spec_map_msg "must be a Map with string keys and Anal protocol-implementing values"

    def prep!(%Spec{} = spec) do
      spec
      |> Common.prep!()
      |> local_prep!()
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

    defp local_prep!(%Spec{exclusive?: ex}) when not is_boolean(ex),
      do: raise(SpecError.new(":exclusive? must be a boolean"))

    defp local_prep!(%Spec{exclusive?: true} = spec)
         when spec.required == %{} and spec.optional == %{},
         do:
           raise(SpecError.new(":required and/or :optional must be used if :exclusive? is true"))

    defp local_prep!(%Spec{optional: optional}) when not is_map(optional),
      do: raise(SpecError.new(":optional " <> @spec_map_msg))

    defp local_prep!(%Spec{required: required}) when not is_map(required),
      do: raise(SpecError.new(":required " <> @spec_map_msg))

    defp local_prep!(%Spec{} = spec) do
      spec
      |> Map.update!(:required, &prep_spec_map!(&1, :required))
      |> Map.update!(:optional, &prep_spec_map!(&1, :optional))
      |> check_for_shared_keys!()
    end

    defp local_exam(%Spec{}, _val), do: :ok

    defp prep_spec_map!(%{} = spec_map, field_name) do
      Map.new(spec_map, fn {key, val} ->
        if not (is_binary(key) and is_spec?(val)),
          do: raise(SpecError.new(inspect(field_name) <> " " <> @spec_map_msg))

        {key, Anal.prep!(val)}
      end)
    end

    defp check_for_shared_keys!(%Spec{} = spec) do
      optional_keys = spec.optional |> Map.keys() |> MapSet.new()
      required_keys = spec.required |> Map.keys() |> MapSet.new()

      shared_keys =
        MapSet.intersection(optional_keys, required_keys) |> MapSet.to_list() |> Enum.join(", ")

      if shared_keys != "" do
        raise(
          SpecError.new(
            "the following keys were in both :optional and :required -- #{shared_keys}"
          )
        )
      else
        spec
      end
    end

    def is_spec?(val), do: Anal.impl_for(val) != nil

    def add_error_message(%Spec{exclusive?: false} = spec)
        when spec.required == %{} and spec.optional == %{} do
      Map.put(spec, :error_message, "must be a map")
    end

    def add_error_message(%Spec{} = spec) when spec.required == %{} and spec.optional != %{} do
      error_message =
        "must be a record with" <>
          if(spec.exclusive?, do: " only", else: "") <>
          " the optional keys " <>
          list_keys(spec.optional)

      Map.put(spec, :error_message, error_message)
    end

    def add_error_message(%Spec{} = spec) when spec.required != %{} and spec.optional == %{} do
      error_message =
        "must be a record with" <>
          if(spec.exclusive?, do: " only", else: "") <>
          " the required keys " <>
          list_keys(spec.required)

      Map.put(spec, :error_message, error_message)
    end

    def add_error_message(%Spec{} = spec) do
      error_message =
        "must be a record with" <>
          if(spec.exclusive?, do: " only", else: "") <>
          " the required keys " <>
          list_keys(spec.required) <>
          " and the optional keys " <>
          list_keys(spec.optional)

      Map.put(spec, :error_message, error_message)
    end

    defp list_keys(%{} = spec_map) do
      spec_map |> Map.keys() |> Enum.sort() |> Enum.map(&~s["#{&1}"]) |> Enum.join(", ")
    end
  end
end

# defmodule Anal.Rec do
#   use Anal.Spec,
#     fields: [required: %{}, optional: %{}, exclusive?: false]
# end

# defimpl Anal.SpecProtocol, for: Anal.Rec do
#   @bad_fields_msg "must be a map or keyword list of field names to specs"

#   def validate_spec(%{exclusive?: exclusive?}) when not is_boolean(exclusive?),
#     do: {:error, ":exclusive? must be a boolean"}

#   def validate_spec(%{required: required, optional: optional} = spec) do
#     with {:ok, transformed_required} <- get_as_map_of_specs(required, :required),
#          {:ok, transformed_optional} <- get_as_map_of_specs(optional, :optional) do
#       transformed_spec =
#         Map.merge(spec, %{required: transformed_required, optional: transformed_optional})

#       {:ok, transformed_spec}
#     end
#   end

#   def get_as_map_of_specs(map, field) when is_map(map) do
#     if is_map_of_specs?(map),
#       do: {:ok, map},
#       else: {:error, "#{inspect(field)} #{@bad_fields_msg}"}
#   end

#   def get_as_map_of_specs(maybe_keyed_specs, field) do
#     if Keyword.keyword?(maybe_keyed_specs) do
#       maybe_keyed_specs
#       |> Map.new()
#       |> get_as_map_of_specs(field)
#     else
#       {:error, "#{inspect(field)} #{@bad_fields_msg}"}
#     end
#   end

#   def is_map_of_specs?(map) do
#     Enum.all?(map, fn {name, val} ->
#       good_name = is_atom(name) or is_binary(name)
#       good_val = Anal.Spec.is_spec?(val)
#       good_name and good_val
#     end)
#   end

#   def validate_val(%{} = _spec, val) when not is_map(val), do: {:error, "must be a map"}

#   def validate_val(%{required: required, optional: optional, exclusive?: exclusive?} = _spec, map) do
#     disallowed_field_errors =
#       if exclusive? do
#         allowed_fields = Map.keys(required) ++ Map.keys(optional)

#         map
#         |> Map.drop(allowed_fields)
#         |> Map.keys()
#         |> Enum.map(fn field -> {[field], "is not allowed"} end)
#       else
#         []
#       end

#     required_field_names = required |> Map.keys() |> MapSet.new()
#     field_names = map |> Map.keys() |> MapSet.new()

#     missing_required_field_names = MapSet.difference(required_field_names, field_names)

#     missing_required_field_errors = Enum.map(missing_required_field_names, &{[&1], "is required"})

#     required_field_errors =
#       required
#       |> Enum.map(fn {field_name, spec} ->
#         if Map.has_key?(map, field_name) do
#           Anal.Spec.recurse(field_name, map[field_name], spec)
#         else
#           :ok
#         end
#       end)
#       |> Enum.filter(&(&1 != :ok))
#       |> List.flatten()

#     optional_field_errors =
#       optional
#       |> Enum.map(fn {field_name, spec} ->
#         if Map.has_key?(map, field_name) do
#           Anal.Spec.recurse(field_name, map[field_name], spec)
#         else
#           :ok
#         end
#       end)
#       |> Enum.filter(&(&1 != :ok))
#       |> List.flatten()

#     all_errors =
#       List.flatten([
#         disallowed_field_errors,
#         missing_required_field_errors,
#         required_field_errors,
#         optional_field_errors
#       ])

#     case all_errors do
#       [] -> :ok
#       errors when is_list(errors) -> {:error, Map.new(errors)}
#     end
#   end
# end
