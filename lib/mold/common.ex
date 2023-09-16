defmodule Mold.Common do
  def prep!(%{__prepped__: true} = mold), do: mold

  def prep!(%{nil_ok?: nil_ok?}) when not is_boolean(nil_ok?),
    do: raise(Mold.Error.new(":nil_ok? must be a boolean"))

  def prep!(%{but: but})
      when not (is_nil(but) or is_function(but, 1)),
      do: raise(Mold.Error.new(":but must be an arity-1 function that returns a boolean"))

  def prep!(%{} = mold), do: mold

  def check_prepped!(%{} = mold) do
    if not mold.__prepped__ do
      raise(Mold.Error.new("you must call Mold.prep/1 on the mold before calling Mold.exam/2"))
    else
      mold
    end
  end

  def exam_nil(%{nil_ok?: false}, nil), do: :error
  def exam_nil(%{nil_ok?: true}, nil), do: :ok
  def exam_nil(%{}, _), do: :not_nil

  def apply_but(%{but: nil}, _val), do: :ok

  def apply_but(%{but: but}, val) do
    case but.(val) do
      true ->
        :ok

      false ->
        :error

      other ->
        raise Mold.Error.new(":but must return a boolean, but it returned #{inspect(other)}")
    end
  end
end
