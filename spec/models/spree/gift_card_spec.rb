require 'spec_helper'

describe Spree::GiftCard, type: :model do

  it { is_expected.to have_many(:transactions) }

  it { is_expected.to validate_presence_of(:current_value) }
  it { is_expected.to validate_presence_of(:email) }
  it { is_expected.to validate_presence_of(:original_value) }
  it { is_expected.to validate_presence_of(:name) }

  it "should generate code before create" do
    card = Spree::GiftCard.create(:email => "test@mail.com", :name => "John", :variant_id => create(:variant).id)
    expect(card.code).not_to be_nil
  end

  it "should set current_value and original_value before create" do
    card = Spree::GiftCard.create(:email => "test@mail.com", :name => "John", :variant_id => create(:variant).id)
    expect(card.current_value).not_to be_nil
    expect(card.original_value).not_to be_nil
  end

  context '#activatable?' do
    let(:gift_card) { create(:gift_card, variant: create(:variant, price: 25)) }

    it 'should be activatable if created before order, has current value, and order state valid' do
      expect(gift_card.order_activatable?(mock_model(Spree::Order, state: 'cart', created_at: (gift_card.created_at + 1.second)))).to be_truthy
    end

    it 'should not be activatable if created after order' do
      expect(gift_card.order_activatable?(mock_model(Spree::Order, state: 'cart', created_at: (gift_card.created_at - 1.second)))).to be_falsey
    end

    it 'should not be activatable if no current value' do
      allow(gift_card).to receive_messages :current_value => 0
      expect(gift_card.order_activatable?(mock_model(Spree::Order, state: 'cart', created_at: (gift_card.created_at + 1.second)))).to be_falsey
    end

    it 'to not be activatable if invalid order state' do
      expect(gift_card.order_activatable?(mock_model(Spree::Order, state: 'complete', created_at: (gift_card.created_at + 1.second)))).to be_falsey
    end
  end

  context '#apply' do
    let(:gift_card) { create(:gift_card, variant: create(:variant, price: 25)) }

    it 'creates adjustment with mandatory set to true' do
      order = create(:order_with_totals)
      create(:line_item, order: order, price: 75, variant: create(:variant, price: 75))
      order.reload # reload so line item is associated
      order.update!
      gift_card.apply(order)
      expect(order.adjustments.find_by_source_id_and_source_type(gift_card.id, gift_card.class.to_s).mandatory).to be_truthy
    end

    context 'for order total larger than gift card amount' do
      it 'creates adjustment for full amount' do
        order = create(:order_with_totals)
        create(:line_item, order: order, price: 75, variant: create(:variant, price: 75))
        order.reload # reload so line item is associated
        order.update!
        gift_card.apply(order)
        expect(order.adjustments.find_by_source_id_and_source_type(gift_card.id, gift_card.class.to_s).amount.to_f).to eql(-25.0)
      end
    end

    context 'for order total smaller than gift card amount' do
      it 'creates adjustment for order total' do
        order = create(:order_with_totals)
        order.reload # reload so line item is associated
        order.update! # update so order calculates totals
        gift_card.apply(order)
        # default line item is priced at 10
        expect(order.adjustments.find_by_source_id_and_source_type(gift_card.id, gift_card.class.to_s).amount.to_f).to eql(-10.0)
      end
    end
  end

  context '#debit' do
    let(:gift_card) { create(:gift_card, variant: create(:variant, price: 25)) }
    let(:order) { create(:order) }

    it 'to raise an error when attempting to debit an amount higher than the current value' do
      expect(lambda {
        gift_card.debit(-30, order)
      }).to raise_error
    end

    it 'should subtract used amount from the current value and create a transaction' do
      gift_card.debit(-25, order)
      gift_card.reload # reload to ensure accuracy
      expect(gift_card.current_value.to_f).to eql(0.0)
      transaction = gift_card.transactions.first
      expect(transaction.amount.to_f).to eql(-25.0)
      expect(transaction.gift_card).to eql(gift_card)
      expect(transaction.order).to eql(order)
    end
  end

end
