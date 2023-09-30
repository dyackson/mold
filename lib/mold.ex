defmodule Mold do
  defdelegate prep!(mold), to: Mold.Protocol
  defdelegate exam(mold, value), to: Mold.Protocol

  defmacro int(args \\ []) do
    quote do
      %Mold.Int{unquote_splicing(args)}
    end
  end

  defmacro str(args \\ []) do
    quote do
      %Mold.Str{unquote_splicing(args)}
    end
  end

  defmacro lst(args \\ []) do
    quote do
      %Mold.Lst{unquote_splicing(args)}
    end
  end

  defmacro boo(args \\ []) do
    quote do
      %Mold.Boo{unquote_splicing(args)}
    end
  end

  defmacro any(args \\ []) do
    quote do
      %Mold.Any{unquote_splicing(args)}
    end
  end

  defmacro dec(args \\ []) do
    quote do
      %Mold.Dec{unquote_splicing(args)}
    end
  end

  defmacro rec(args \\ []) do
    quote do
      %Mold.Rec{unquote_splicing(args)}
    end
  end

  defmacro dic(args \\ []) do
    quote do
      %Mold.Dic{unquote_splicing(args)}
    end
  end
end
