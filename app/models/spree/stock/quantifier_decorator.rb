module Spree
  module Stock
    Quantifier.class_eval do

      alias_method :original_can_supply?, :can_supply?

      def can_supply?(required=1)
        if @variant.is_a?(Integer)
          original_can_supply?(required) || Spree::Variant.find(@variant).product.is_gift_card?
        else
          original_can_supply?(required) || @variant.product.is_gift_card?
        end

      end
    end
  end
end
