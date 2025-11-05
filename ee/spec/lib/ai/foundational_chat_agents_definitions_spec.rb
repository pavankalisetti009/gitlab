# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FoundationalChatAgentsDefinitions, feature_category: :ai_abstraction_layer do
  let(:dummy_class) do
    Class.new do
      include Ai::FoundationalChatAgentsDefinitions
    end
  end

  describe 'module inclusion' do
    it 'can be included in other classes' do
      expect { dummy_class.new }.not_to raise_error
    end
  end

  describe 'ITEMS constant' do
    let(:items) { described_class::ITEMS }

    it 'is an array' do
      expect(items).to be_an(Array)
    end

    it 'is not empty' do
      expect(items).not_to be_empty
    end

    it 'is frozen' do
      expect(items).to be_frozen
    end

    describe 'item structure' do
      it 'has required keys for each item' do
        expect(items).to all(include(:id, :reference, :version, :name, :description))
      end

      it 'has unique IDs' do
        ids = items.pluck(:id)
        expect(ids.uniq.size).to eq(ids.size)
      end

      it 'has unique references' do
        references = items.pluck(:reference)
        expect(references.uniq.size).to eq(references.size)
      end

      it 'has sequential IDs starting from 1' do
        ids = items.pluck(:id).sort
        expect(ids).to eq((1..items.size).to_a)
      end
    end

    describe 'data validation' do
      it 'has valid data types for all required fields' do
        items.each do |item|
          expect(item[:id]).to be_a(Integer).and be_present
          expect(item[:reference]).to be_a(String).and be_present
          expect(item[:version]).to be_a(String) # version can be empty string
          expect(item[:name]).to be_a(String).and be_present
          expect(item[:description]).to be_a(String).and be_present
        end
      end

      it 'has positive integer IDs' do
        items.each do |item|
          expect(item[:id]).to be_a(Integer).and be_positive
        end
      end

      it 'has non-empty strings for name and description' do
        items.each do |item|
          expect(item[:name]).not_to be_empty
          expect(item[:description]).not_to be_empty
        end
      end

      it 'has non-empty strings for reference' do
        items.each do |item|
          expect(item[:reference]).not_to be_empty
        end
      end
    end

    describe 'agent versions' do
      it 'has appropriate version formats' do
        items.each do |item|
          version = item[:version]
          # Version should be either empty string or follow semantic versioning pattern
          expect(version).to match(/\A(|v\d+(\.\d+)*|experimental)\z/)
        end
      end
    end
  end
end
