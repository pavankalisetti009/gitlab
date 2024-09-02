# frozen_string_literal: true

# Requires the following pre-defined variable/subject:
#   `add_on_license`: Initialized add-on license class, example: `<class_name>.new(restrictions)`
#
# Requires the add-on name to be passed in as a String, example: "duo_pro"
RSpec.shared_examples "license add-on attributes" do |add_on_name:|
  subject(:add_on_quantity) { add_on_license.quantity }

  let(:quantity) { 10 }
  let(:add_on_products) do
    {
      add_on_name => [{ "quantity" => quantity }]
    }
  end

  let(:restrictions) do
    { add_on_products: add_on_products }
  end

  it { is_expected.to eq(10) }

  context "without restrictions" do
    let(:restrictions) { nil }

    it { is_expected.to eq(0) }
  end

  context "without the add-on info" do
    let(:add_on_products) do
      {
        "add_on" => [{ "quantity" => quantity }]
      }
    end

    it { is_expected.to eq(0) }
  end

  context "with mixed hash key types" do
    let(:add_on_products) do
      {
        add_on_name => [{ quantity: quantity }]
      }
    end

    it { is_expected.to eq(10) }
  end

  context "without a quantity" do
    let(:add_on_products) do
      {
        add_on_name => [{ 'another_key' => 1 }]
      }
    end

    it { is_expected.to eq(0) }
  end

  context "with multiple purchases" do
    let(:add_on_products) do
      {
        add_on_name => [
          { "quantity" => quantity * 2 },
          { "quantity" => quantity }
        ]
      }
    end

    it { is_expected.to eq(30) }
  end
end
