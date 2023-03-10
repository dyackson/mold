defmodule Anal do
  @moduledoc """
  Documentation for `Anal`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Anal.hello()
      :world

  """
  def hello do
    :world
  end

  @type path :: [atom() | String.t() | non_neg_integer()]
  @callback validate(val :: any(), spec :: Anal.Spec.t()) ::
              :ok | {:error, String.t()} | {:error, %{optional(path) => String.t()}}

  def validate(val, spec) do
    Anal.SpecProtocol.impl_for!(spec)

    case {val, spec} do
      {nil, %{nullable: true}} ->
        :ok

      {nil, %{nullable: false}} ->
        {:error, "cannot be nil"}

      {_, _} ->
        with :ok <- Anal.SpecProtocol.validate_val(spec, val) do
          apply_and_fn(spec.and_fn, val)
        end
    end
  end

  defp apply_and_fn(fun, val) when is_function(fun) do
    case fun.(val) do
      :ok -> :ok
      {:error, msg} when is_binary(msg) -> {:error, msg}
    end
  end

  defp apply_and_fn(_fun, _val), do: :ok
end
