defmodule Dammit.MapSpec do
  use Dammit.Spec,
    fields: [required: %{}, optional: %{}, exclusive: false]
end

defimpl Dammit.ValidateSpec, for: Dammit.MapSpec do
  @bad_fields_msg "must be a map or keyword list of field names to specs"

  def validate_spec(%{exclusive: exclusive}) when not is_boolean(exclusive),
    do: {:error, ":exclusive must be a boolean"}

  def validate_spec(%{required: required, optional: optional} = spec) do
    with {:ok, transformed_required} <- get_as_map_of_specs(required, :required),
         {:ok, transformed_optional} <- get_as_map_of_specs(optional, :optional) do
      transformed_spec =
        Map.merge(spec, %{required: transformed_required, optional: transformed_optional})

      {:ok, transformed_spec}
    end
  end

  def get_as_map_of_specs(map, field) when is_map(map) do
    if is_map_of_specs?(map),
      do: {:ok, map},
      else: {:error, "#{inspect(field)} #{@bad_fields_msg}"}
  end

  def get_as_map_of_specs(maybe_keyed_specs, field) do
    if Keyword.keyword?(maybe_keyed_specs) do
      maybe_keyed_specs
      |> Map.new()
      |> get_as_map_of_specs(field)
    else
      {:error, "#{inspect(field)} #{@bad_fields_msg}"}
    end
  end

  def is_map_of_specs?(map) do
    Enum.all?(map, fn {name, val} ->
      good_name = is_atom(name) or is_binary(name)
      good_val = Dammit.Spec.is_spec?(val)
      good_name and good_val
    end)
  end
end

defimpl Dammit.ValidateVal, for: Dammit.MapSpec do
  def validate_val(%{} = _spec, val) when not is_map(val), do: {:error, "must be a map"}

  def validate_val(%{required: required, optional: optional, exclusive: exclusive} = _spec, map) do
    disallowed_field_errors =
      if exclusive do
        allowed_fields = Map.keys(required) ++ Map.keys(optional)

        map
        |> Map.drop(allowed_fields)
        |> Map.keys()
        |> Enum.map(fn field -> {[field], "is not allowed"} end)
      else
        []
      end

    required_field_names = required |> Map.keys() |> MapSet.new()
    field_names = map |> Map.keys() |> MapSet.new()

    missing_required_field_names = MapSet.difference(required_field_names, field_names)

    missing_required_field_errors = Enum.map(missing_required_field_names, &{[&1], "is required"})

    required_field_errors =
      required
      |> Enum.map(fn {field_name, spec} ->
        if Map.has_key?(map, field_name) do
          Dammit.Spec.recurse(field_name, map[field_name], spec)
        else
          :ok
        end
      end)
      |> Enum.filter(&(&1 != :ok))
      |> List.flatten()

    optional_field_errors =
      optional
      |> Enum.map(fn {field_name, spec} ->
        if Map.has_key?(map, field_name) do
          Dammit.Spec.recurse(field_name, map[field_name], spec)
        else
          :ok
        end
      end)
      |> Enum.filter(&(&1 != :ok))
      |> List.flatten()

    all_errors =
      List.flatten([
        disallowed_field_errors,
        missing_required_field_errors,
        required_field_errors,
        optional_field_errors
      ])

    case all_errors do
      [] -> :ok
      errors when is_list(errors) -> {:error, Map.new(errors)}
    end
  end
end
