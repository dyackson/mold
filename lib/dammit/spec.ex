defmodule Dammit.Spec do
  @base_fields [nullable: false, also: nil]

  defmacro __using__(opts \\ []) do
    fields = Keyword.get(opts, :fields, [])
    fields = fields ++ @base_fields

    quote do
      defstruct unquote(fields)
      alias Dammit.Spec

      def new(opts \\ []) do
        with {:ok, spec} <- Spec.create_spec(__MODULE__, opts),
             :ok <- Spec.validate_base_fields(spec),
             :ok <- Spec.check_required_fields(__MODULE__, spec),
             {:ok, spec} <- Spec.wrap_validate_spec(__MODULE__, spec) do
          spec
        else
          {:error, reason} -> raise Dammit.SpecError.new(reason)
        end
      end
    end
  end

  def wrap_validate_spec(module, spec) do
    case Dammit.SpecProtocol.validate_spec(spec) do
      :ok -> {:ok, spec}
      # this gives the implementation a chance to transform the spec
      {:ok, %^module{} = spec} -> {:ok, spec}
      {:error, reason} -> {:error, reason}
    end
  end

  def validate_base_fields(%{nullable: val}) when not is_boolean(val),
    do: {:error, ":nullable must be a boolean, got #{inspect(val)}"}

  def validate_base_fields(%{also: also_fn})
      when not is_nil(also_fn) and not is_function(also_fn, 1),
      do: {:error, ":also must be a 1-arity function, got #{inspect(also_fn)}"}

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

  def validate(val, spec) do
    Dammit.SpecProtocol.impl_for!(spec)

    case {val, spec} do
      {nil, %{nullable: true}} ->
        :ok

      {nil, %{nullable: false}} ->
        {:error, "cannot be nil"}

      {_, _} ->
        with :ok <- Dammit.SpecProtocol.validate_val(spec, val) do
          apply_also(spec.also, val)
        end
    end
  end

  def apply_also(fun, val) when is_function(fun) do
    case fun.(val) do
      :ok -> :ok
      {:error, msg} when is_binary(msg) -> {:error, msg}
    end
  end

  def apply_also(_fun, _val), do: :ok

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

  def is_spec?(val), do: Dammit.SpecProtocol.impl_for(val) != nil
end
