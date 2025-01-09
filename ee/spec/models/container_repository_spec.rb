# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContainerRepository, :saas do
  include_examples 'a verifiable model with a separate table for verification state' do
    let(:verifiable_model_record) { build(:container_repository) }
    let(:unverifiable_model_record) { nil }
  end

  describe '#push_blob' do
    let_it_be(:gitlab_container_repository) { create(:container_repository) }

    it "calls client's push blob with path passed" do
      client = instance_double("ContainerRegistry::Client")
      allow(gitlab_container_repository).to receive(:client).and_return(client)

      expect(client).to receive(:push_blob).with(gitlab_container_repository.path, 'a123cd', ['body'], 32456)

      gitlab_container_repository.push_blob('a123cd', ['body'], 32456)
    end
  end

  describe '.search' do
    let_it_be(:container_repository1) { create(:container_repository) }
    let_it_be(:container_repository2) { create(:container_repository) }
    let_it_be(:container_repository3) { create(:container_repository) }

    context 'when search query is empty' do
      it 'returns all records' do
        result = described_class.search('')

        expect(result).to contain_exactly(container_repository1, container_repository2, container_repository3)
      end
    end

    context 'when search query is not empty' do
      context 'without matches' do
        it 'filters all container repositories' do
          result = described_class.search('something_that_does_not_exist')

          expect(result).to be_empty
        end
      end

      context 'with matches' do
        context 'with matches by attributes' do
          where(:searchable_attributes) { described_class::EE_SEARCHABLE_ATTRIBUTES }

          before do
            # Use update_column to bypass attribute validations like regex formatting, checksum, etc.
            container_repository1.update_column(searchable_attributes, 'any_keyword')
          end

          with_them do
            it do
              result = described_class.search('any_keyword')

              expect(result).to contain_exactly(container_repository1)
            end
          end
        end
      end
    end
  end
end
