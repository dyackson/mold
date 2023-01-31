defmodule Dammit.Spec do
  @base_fields [nullable: false, and: nil]

  defmacro __using__(opts \\ []) do
    fields = Keyword.get(opts, :fields, [])
    fields = fields ++ @base_fields

    quote do
      defstruct unquote(fields)

      def new(opts \\ []) do
        with {:ok, spec} <- Dammit.Spec.create_spec(__MODULE__, opts),
             :ok <- Dammit.Spec.validate_base_fields(spec),
             :ok <- Dammit.Spec.check_required_fields(__MODULE__, spec),
             {:ok, spec} <- Dammit.Spec.wrap_validate_spec(__MODULE__, spec) do
          spec
        else
          {:error, reason} -> raise Dammit.SpecError.new(reason)
        end
      end
    end
  end

  def wrap_validate_spec(module, spec) do
    case Dammit.ValidateSpec.validate_spec(spec) do
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

  def validate_base_fields(_spec), do: :ok

  def check_required_fields(module, spec) do
    missing_field =
      spec
      |> Map.from_struct()
      # To define a spec field as required, give it a default value of
      # :required. If the user doesn't specifiy a val when creating the spec,
      # :required will remain.
      |> Enum.find(fn {_field, val} -> val == :required end)

    case missing_field do
      nil -> :ok
      {field, _val} -> {:error, "#{inspect(field)} is required in #{inspect(module)}"}
    end
  end

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
    with :ok <- Dammit.ValidateVal.validate_val(spec, val) do
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

  def recurse(key_in_parent, value, spec) when is_map(spec) do
    case validate(value, spec) do
      :ok ->
        :ok

      {:error, error_msg} when is_binary(error_msg) ->
        {[key_in_parent], error_msg}

      {:error, error_map} when is_map(error_map) ->
        Enum.map(error_map, fn {path, error_msg} when is_list(path) and is_binary(error_msg) ->
          {[key_in_parent | path], error_msg}
        end)
    end
  end

  def is_spec?(val) do
    not (val |> Dammit.ValidateSpec.impl_for() |> is_nil()) and
      not (val |> Dammit.ValidateVal.impl_for() |> is_nil())
  end
end

defprotocol Dammit.ValidateSpec do
  def validate_spec(spec)
end

defprotocol Dammit.ValidateVal do
  def validate_val(spec, value)
end

defimpl Dammit.ValidateSpec, for: Any do
  def validate_spec(_spec), do: :ok
end

defimpl Dammit.ValidateVal, for: Any do
  def validate_val(_spec, _val), do: :ok
end

