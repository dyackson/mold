defmodule Anal.Common do
  def prep!(%{__prepped__: true} = spec), do: spec

  def prep!(%{nil_ok?: nil_ok?}) when not is_boolean(nil_ok?),
    do: raise(Anal.SpecError.new(":is_nil must be a boolean"))

  def prep!(%{get_error_message: get_em})
      when not (is_nil(get_em) or is_function(get_em, 1)),
      do: raise(Anal.SpecError.new(":get_error_message be a single-arg function"))

  def prep!(%{also: also})
      when not (is_nil(also) or is_function(also, 1)),
      do: raise(Anal.SpecError.new(":also must be a single-arg function"))

  def prep!(%{} = spec) do
    error_message =
      case spec.get_error_message do
        nil ->
          if spec.nil_ok?, do: "if not nil, must be a boolean", else: "must be a boolean"

        fun1 when is_function(fun1, 1) ->
          fun1.get_error_message(spec)
      end

    spec |> Map.put(:__error_message__, error_message)
  end

  def check_prepped!(%{} = spec) do
    if not spec.__prepped__ do
      raise(Anal.SpecError.new("you must call Anal.prep/1 on the spec before calling exam/2"))
    else
      spec
    end
  end

  def exam_nil(%{nil_ok?: false}, nil), do: :error
  def exam_nil(%{nil_ok?: true}, nil), do: :ok
  def exam_nil(%{}, _), do: :not_nil

  def apply_also(%{also: nil}, _val), do: :ok

  def apply_also(%{also: also}, val) do
    if also.(val), do: :ok, else: :error
  end
end
