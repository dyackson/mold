defprotocol Mold do
  def prep!(spec)
  def exam(spec, value)
end
