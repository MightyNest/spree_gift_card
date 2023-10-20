module Spree
  module QuantifierCanSupply
    def can_supply?(required=1)
      if @variant.is_a?(Integer)
        super || Spree::Variant.find(@variant).product.is_gift_card?
      else
        super || @variant.product.is_gift_card?
      end
    end
  end
end