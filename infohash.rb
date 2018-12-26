# -*- encoding: utf-8 -*-

class Infohash
  def initialize(value)
    first  = self.value[0, 2]
    second = self.value[-2, 2]
    self.btbox = "http://bt.box.n0808.com/#{first}/#{second}/#{self.value}.torrent"
  end
end


