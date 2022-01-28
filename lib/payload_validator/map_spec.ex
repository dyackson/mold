defmodule PayloadValidator.MapSpec do
  use PayloadValidator.Spec,
    conform_fn_name: :map,
    fields: [fields: %{}, exclusive: false]

  alias PayloadValidator.Spec

  @bad_fields_msg "fields must be a map of field names to specs"

  def check_spec(%__MODULE__{fields: fields}) when not is_map(fields),
    do: {:error, @bad_fields_msg}

  def check_spec(%__MODULE__{exclusive: exclusive}) when not is_boolean(exclusive),
    do: {:error, "exclusive must be a boolean"}

  def check_spec(%__MODULE__{fields: fields}) do
    good =
      Enum.all?(fields, fn {name, val} ->
        good_name = is_atom(name) or is_binary(name)

        good_val = Spec.is_spec?(val)

        good_name and good_val
      end)

    if good, do: :ok, else: {:error, @bad_fields_msg}
  end

  def check_spec(%__MODULE__{}), do: :ok

  def conform(val, %__MODULE__{}) when not is_map(val), do: {:error, "must be a map"}

  def conform(map, %__MODULE__{fields: fields, exclusive: exclusive}) do
    disallowed_field_errors =
      if exclusive do
        allowed_fields = Map.keys(fields)

        map
        |> Map.drop(allowed_fields)
        |> Map.keys()
        |> Enum.map(fn field -> {[field], "is not allowed"} end)
      else
        []
      end

    allowed_field_errors =
      fields
      |> Enum.map(fn {field_name, spec} ->
        cond do
          spec.required && !Map.has_key?(map, field_name) ->
            {[field_name], "is required"}

          !spec.required && !Map.has_key?(map, field_name) ->
            :ok

          true ->
            Spec.recurse(field_name, map[field_name], spec)
        end
      end)
      |> Enum.filter(&(&1 != :ok))
      |> List.flatten()

    case allowed_field_errors ++ disallowed_field_errors do
      [] -> :ok
      errors when is_list(errors) -> {:error, Map.new(errors)}
    end
  end
end
