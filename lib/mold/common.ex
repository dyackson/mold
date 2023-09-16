defmodule Mold.Common do
  def prep!(%{__prepped__: true} = spec), do: spec

  def prep!(%{nil_ok?: nil_ok?}) when not is_boolean(nil_ok?),
    do: raise(Mold.Error.new(":nil_ok? must be a boolean"))

  def prep!(%{also: also})
      when not (is_nil(also) or is_function(also, 1)),
      do: raise(Mold.Error.new(":also must be an arity-1 function that returns a boolean"))

  def prep!(%{} = spec), do: spec

  def check_prepped!(%{} = spec) do
    if not spec.__prepped__ do
      raise(Mold.Error.new("you must call Mold.prep/1 on the spec before calling Mold.exam/2"))
    else
      spec
    end
  end

  def exam_nil(%{nil_ok?: false}, nil), do: :error
  def exam_nil(%{nil_ok?: true}, nil), do: :ok
  def exam_nil(%{}, _), do: :not_nil

  def apply_also(%{also: nil}, _val), do: :ok

  def apply_also(%{also: also}, val) do
    case also.(val) do
      true ->
        :ok

      false ->
        :error

      other ->
        raise Mold.Error.new(":also must return a boolean, but it returned #{inspect(other)}")
    end
  end
end
