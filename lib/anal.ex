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

  # todo just make Anal a protocol|>k  def validate(val, spec), do: Anal.SpecProtocol.validate_val(spec, val)

  defp apply_and_fn(fun, val) when is_function(fun) do
    case fun.(val) do
      :ok -> :ok
      {:error, msg} when is_binary(msg) -> {:error, msg}
    end
  end

  defp apply_and_fn(_fun, _val), do: :ok
end
