# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Attributes::CreateService, feature_category: :security_asset_inventories do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group) }
  let_it_be_with_reload(:category) { create(:security_category, namespace: namespace, editable_state: :editable) }

  let(:params) do
    {
      attributes: [
        {
          name: 'Critical',
          description: 'Critical security level',
          color: '#FF0000'
        },
        {
          name: 'High',
          description: 'High security level',
          color: '#FF8C00'
        }
      ]
    }
  end

  subject(:execute) do
    described_class.new(
      category: category,
      namespace: namespace,
      params: params,
      current_user: user
    ).execute
  end

  describe '#execute' do
    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(security_categories_and_attributes: false)
      end

      it 'raises an access denied error' do
        expect { execute }.to raise_error(Gitlab::Access::AccessDeniedError)
      end
    end

    context 'when feature flag is enabled' do
      before do
        stub_feature_flags(security_categories_and_attributes: true)
      end

      context 'when user does not have permission' do
        it 'returns an error' do
          expect(execute).to be_error
          expect(execute.message).to eq('You are not authorized to perform this action')
        end
      end

      context 'when user has permission' do
        before_all do
          namespace.add_owner(user)
        end

        it 'creates security attributes successfully' do
          expect { execute }.to change { Security::Attribute.count }.by(2)

          expect(execute).to be_success
          expect(execute.payload[:attributes].size).to eq(2)

          attribute1 = execute.payload[:attributes].first
          expect(attribute1.name).to eq('Critical')
          expect(attribute1.description).to eq('Critical security level')
          expect(attribute1.color).to eq(::Gitlab::Color.of('#FF0000'))
          expect(attribute1.editable_state).to eq('editable')
          expect(attribute1.security_category).to eq(category)
          expect(attribute1.namespace).to eq(namespace)
        end

        it 'creates all attributes in a single transaction' do
          expect(category).to receive(:save).once.and_call_original

          expect(execute).to be_success
        end

        context 'when attribute validation fails' do
          let(:params) { { attributes: [{ name: '', description: 'Test description', color: '#FF0000' }] } }

          it 'returns error without creating any attributes' do
            expect { execute }.not_to change { Security::Attribute.count }

            expect(execute).to be_error
            expect(execute.message).to include('Failed to create security attributes')
            expect(execute.message).to include("Name can't be blank")
          end
        end

        context 'when color validation fails' do
          let(:params) do
            {
              attributes: [
                {
                  name: 'Test',
                  description: 'Test description',
                  color: 'invalid-color' # Invalid color format
                }
              ]
            }
          end

          it 'returns error with color validation message' do
            expect(execute).to be_error
            expect(execute.message).to include('Failed to create security attributes')
            expect(execute.message).to include('Color')
          end
        end

        context 'when duplicate name within category' do
          let!(:existing_attribute) do
            create(:security_attribute, security_category: category, name: 'Critical', namespace: namespace)
          end

          it 'returns error for duplicate name' do
            expect(execute).to be_error
            expect(execute.message).to include('Name has already been taken')
          end
        end

        context 'when exceeding attribute limit' do
          let(:limit) { 5 }

          before do
            stub_const("Security::Category::MAX_ATTRIBUTES", limit)
            create_list(:security_attribute, limit - 1, security_category: category, namespace: namespace)
          end

          context 'when at limit' do
            let(:params) do
              {
                attributes: [{ name: "#{limit} Attribute", description: "The best attribute", color: '#000000' }]
              }
            end

            it 'creates attributes' do
              expect { execute }.to change { Security::Attribute.count }.by(1)
              expect(execute).to be_success
            end
          end

          context 'when exceeding limit' do
            let(:params) do
              {
                attributes: [
                  { name: 'Extra Attribute', description: 'Should not be allowed', color: '#123456' },
                  { name: 'Another One', description: 'Also too much', color: '#654321' }
                ]
              }
            end

            it 'returns error' do
              expect { execute }.not_to change { Security::Attribute.count }
              expect(execute).to be_error
              expect(execute.message).to include("cannot have more than #{limit} attributes per category")
            end
          end
        end

        context 'when description is missing' do
          let(:params) { { attributes: [{ name: 'Test', description: nil, color: '#FF0000' }] } }

          it 'returns validation error' do
            expect(execute).to be_error
            expect(execute.message).to include("Description can't be blank")
          end
        end
      end
    end
  end
end
