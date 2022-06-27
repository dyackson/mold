defmodule PayloadValidator.Spex do
  @base_fields [nullable: false, and: nil]

  defmacro __using__(opts \\ []) do
    fields = Keyword.get(opts, :fields, [])
    fields = fields ++ @base_fields

    quote do
      defstruct unquote(fields)

      def new(opts \\ []) do
        with {:ok, spec} <- PayloadValidator.Spex.create_spec(__MODULE__, opts) ,
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
    case PayloadValidator.SpexProtocol.validate_spec(spec) do
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
    with :ok <- PayloadValidator.SpexProtocol.validate_val(spec, val) do
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
end

defprotocol PayloadValidator.SpexProtocol do
  @fallback_to_any true
  def validate_spec(spec)
  def validate_val(spec, value)
end

defimpl PayloadValidator.SpexProtocol, for: Any do
  def validate_spec(_spec), do: :ok
  def validate_val(_spec, _val), do: :ok
end

defmodule PayloadValidator.Spex.String do
  use PayloadValidator.Spex, fields: [:regex]
end

defimpl PayloadValidator.SpexProtocol, for: PayloadValidator.Spex.String do
  # TODO: add enum vals
  def validate_spec(%{regex: regex} = spec) do
    case regex do
      nil -> {:ok, spec}
      %Regex{} -> :ok
      _ -> {:error, ":regex must be a Regex"}
    end
  end

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
