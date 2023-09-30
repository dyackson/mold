defprotocol Mold.Protocol do
  def prep!(mold)

  def exam(mold, value)
end
