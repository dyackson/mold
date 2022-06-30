defmodule PayloadValidator.Misc do
end

defmodule PayloadValidator.Spex do
  @base_fields [nullable: false, and: nil]

  defmacro __using__(opts \\ []) do
    fields = Keyword.get(opts, :fields, [])
    fields = fields ++ @base_fields

    quote do
      defstruct unquote(fields)

      def new(opts \\ []) do
        with {:ok, spec} <- PayloadValidator.Spex.create_spec(__MODULE__, opts),
             {:ok, spec} <- PayloadValidator.Spex.validate_base_fields(spec),
             {:ok, spec} <- PayloadValidator.Spex.wrap_validate_spec(__MODULE__, spec) do
          spec
        else
          {:error, reason} -> raise PayloadValidator.SpecError.new(reason)
        end
      end
    end
  end

  def wrap_validate_spec(module, spec) do
    case PayloadValidator.ValidateSpec.validate_spec(spec) do
      :ok -> {:ok, spec}
      # this gives the implementation a chance to transform the spec
      {:ok, %^module{} = spec} -> {:ok, spec}
      {:error, reason} -> {:error, reason}
    end
  end

  def validate_base_fields(%{nullable: val}) when not is_boolean(val),
    do: {:error, ":nullable must be a boolean, got #{inspect(val)}"}

  def validate_base_fields(%{and: and_fn}) when not is_nil(and_fn) and not is_function(and_fn, 1),
    do: {:error, ":and must be a 1-arity function, got #{inspect(and_fn)}"}

  def validate_base_fields(spec), do: {:ok, spec}

  def create_spec(module, opts) do
    try do
      {:ok, struct!(module, opts)}
    rescue
      e in KeyError -> {:error, "#{inspect(e.key)} is not a field of #{inspect(module)}"}
    end
  end

  def get_name(module) do
    ["Elixir" | split_module_name] = module |> to_string() |> String.split(".")
    Enum.join(split_module_name, ".")
  end

  # TODO: maybe have an intermediate public function that checks that the spec is a spec
  # However, we want to avoid double checking all the specs in maps
  def validate(nil, %{nullable: true}), do: :ok
  def validate(nil, %{nullable: false}), do: {:error, "cannot be nil"}

  def validate(val, %{and: and_fn} = spec) do
    # first conform according to the module, then test the value agaist the :and function only if successful
    # delete the and so the implementer can't override the and behavior
    with :ok <- PayloadValidator.ValidateVal.validate_val(spec, val) do
      apply_and_fn(and_fn, val)
    end
  end

  def apply_and_fn(fun, val) when is_function(fun) do
    case fun.(val) do
      :ok -> :ok
      true -> :ok
      false -> {:error, "invalid"}
      msg when is_binary(msg) -> {:error, msg}
      {:error, msg} when is_binary(msg) -> {:error, msg}
    end
  end

  def apply_and_fn(_fun, _val), do: :ok

  def recurse(key, value, spec) when is_map(spec) do
    case validate(value, spec) do
      :ok ->
        :ok

      {:error, error_msg} when is_binary(error_msg) ->
        {[key], error_msg}

      {:error, error_map} when is_map(error_map) ->
        Enum.map(error_map, fn {path, error_msg} when is_list(path) and is_binary(error_msg) ->
          {[key | path], error_msg}
        end)
    end
  end

  def is_spec?(val) do
    not (val |> PayloadValidator.ValidateSpec.impl_for() |> is_nil()) and
      not (val |> PayloadValidator.ValidateVal.impl_for() |> is_nil())
  end
end

defprotocol PayloadValidator.ValidateSpec do
  def validate_spec(spec)
end

defprotocol PayloadValidator.ValidateVal do
  def validate_val(spec, value)
end

defimpl PayloadValidator.ValidateSpec, for: Any do
  def validate_spec(_spec), do: :ok
end

defimpl PayloadValidator.ValidateVal, for: Any do
  def validate_val(_spec, _val), do: :ok
end

defmodule PayloadValidator.Spex.String do
  use PayloadValidator.Spex, fields: [:regex]
end

defimpl PayloadValidator.ValidateSpec, for: PayloadValidator.Spex.String do
  # TODO: add enum vals
  def validate_spec(%{regex: regex} = spec) do
    case regex do
      nil -> {:ok, spec}
      %Regex{} -> :ok
      _ -> {:error, ":regex must be a Regex"}
    end
  end
end

defimpl PayloadValidator.ValidateVal, for: PayloadValidator.Spex.String do
  def validate_val(_spec, val) when not is_binary(val), do: {:error, "must be a string"}

  def validate_val(%{regex: regex}, val) when not is_nil(regex) do
    if Regex.match?(regex, val) do
      :ok
    else
      {:error, "must match regex: #{Regex.source(regex)}"}
    end
  end

  def validate_val(_spec, _val), do: :ok
end

defmodule PayloadValidator.Spex.Boolean do
  @derive [PayloadValidator.ValidateSpec]
  use PayloadValidator.Spex
end

defimpl PayloadValidator.ValidateVal, for: PayloadValidator.Spex.Boolean do
  def validate_val(_spec, val) when is_boolean(val), do: :ok
  def validate_val(_spec, _val), do: {:error, "must be a boolean"}
end

defmodule PayloadValidator.Spex.Integer do
  @derive [PayloadValidator.ValidateSpec]
  use PayloadValidator.Spex
end

defimpl PayloadValidator.ValidateVal, for: PayloadValidator.Spex.Integer do
  def validate_val(_spec, val) when is_integer(val), do: :ok
  def validate_val(_spec, _val), do: {:error, "must be an integer"}
end

defmodule PayloadValidator.Spex.Map do
  use PayloadValidator.Spex,
    fields: [required: %{}, optional: %{}, exclusive: false]
end

defimpl PayloadValidator.ValidateSpec, for: PayloadValidator.Spex.Map do
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
      good_val = PayloadValidator.Spex.is_spec?(val)
      good_name and good_val
    end)
  end
end

defimpl PayloadValidator.ValidateVal, for: PayloadValidator.Spex.Map do
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
          PayloadValidator.Spex.recurse(field_name, map[field_name], spec)
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
          PayloadValidator.Spex.recurse(field_name, map[field_name], spec)
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
