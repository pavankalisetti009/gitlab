# frozen_string_literal: true

RSpec.shared_examples Integrations::Base::AmazonQ do
  subject(:integration) { described_class.new }

  describe 'Validations' do
    context 'when active' do
      before do
        subject.active = true
      end

      it { is_expected.to validate_presence_of(:role_arn) }
    end

    context 'when inactive' do
      it { is_expected.not_to validate_presence_of(:role_arn) }
    end
  end

  describe '#execute' do
    let_it_be(:user) { create(:user) }

    it 'does not send events if user is not passed' do
      expect(::Gitlab::Llm::QAi::Client).not_to receive(:new)

      integration.execute({ some_data: :data })
    end

    context 'when a user can be found', :request_store do
      using RSpec::Parameterized::TableSyntax

      where(:object_kind, :event_id) do
        :pipeline | 'Pipeline Hook'
        :merge_request | 'Merge Request Hook'
      end

      with_them do
        it 'sends an event to amazon q' do
          data = { object_kind: object_kind, user: { id: user.id } }

          ::Ai::Setting.instance.update!(amazon_q_role_arn: 'role-arn')

          expect_next_instance_of(::Gitlab::Llm::QAi::Client, user) do |instance|
            expect(instance).to receive(:create_event).with(
              payload: { source: :web_hook, data: data },
              role_arn: 'role-arn',
              event_id: event_id
            )
          end

          integration.execute(data)
        end
      end

      context 'and the user is a composite identity' do
        let_it_be(:composite_identity_user) { create(:user, :service_account, composite_identity_enforced: true) }
        let_it_be(:data) { { object_kind: :pipeline, user: { id: composite_identity_user.id } } }

        it 'does not send events if user is not passed' do
          expect(::Gitlab::Llm::QAi::Client).not_to receive(:new)

          integration.execute(data)
        end

        context 'and it is scoped to a user' do
          before do
            ::Gitlab::Auth::Identity.fabricate(composite_identity_user).link!(user)
          end

          it 'sends an event to amazon q' do
            ::Ai::Setting.instance.update!(amazon_q_role_arn: 'role-arn')

            expect_next_instance_of(::Gitlab::Llm::QAi::Client, user) do |instance|
              expect(instance).to receive(:create_event).with(
                payload: { source: :web_hook, data: data },
                role_arn: 'role-arn',
                event_id: 'Pipeline Hook'
              )
            end

            integration.execute(data)
          end
        end
      end
    end

    context 'when amazon_q_chat_and_code_suggestions is disabled' do
      before do
        stub_feature_flags(amazon_q_chat_and_code_suggestions: false)
      end

      it 'does not send events' do
        expect(::Gitlab::Llm::QAi::Client).not_to receive(:new)

        integration.execute({ object_kind: :pipeline, user: { id: user.id } })
      end
    end
  end

  describe '#sections' do
    it 'returns section configuration' do
      expect(integration.sections).to eq([{
        type: 'amazon_q',
        title: 'Configure GitLab Duo with Amazon Q',
        description: described_class.help,
        plan: 'ultimate'
      }])
    end
  end

  describe '#editable?' do
    it 'returns false' do
      expect(integration.editable?).to be false
    end
  end

  describe 'class methods' do
    describe '.title' do
      it 'returns the correct title' do
        expect(described_class.title).to eq('Amazon Q')
      end
    end

    describe '.description' do
      it 'returns the correct description' do
        expect(described_class.description).to eq(
          'Use GitLab Duo with Amazon Q to create and review merge requests and upgrade Java.'
        )
      end
    end

    describe '.help' do
      it 'returns a valid help URL' do
        expect(described_class.help).to match(%r{http.+duo_amazon_q/index\.md})
      end

      it 'includes relevant information' do
        expect(described_class.help).to include(described_class.description)
        expect(described_class.help).to include(
          'GitLab Duo with Amazon Q is separate from GitLab Duo Pro and Enterprise.'
        )
      end
    end

    describe '.to_param' do
      it 'returns the correct parameter name' do
        expect(described_class.to_param).to eq('amazon_q')
      end
    end

    describe '.supported_events' do
      it 'returns supported events for web hooks' do
        expect(described_class.supported_events).to eq(%w[merge_request pipeline])
      end
    end
  end
end
