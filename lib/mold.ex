defmodule Mold do
  defdelegate prep!(mold), to: Mold.Protocol
  defdelegate exam(mold, value), to: Mold.Protocol
end
