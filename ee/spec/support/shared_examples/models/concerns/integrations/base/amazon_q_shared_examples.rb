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
    it 'returns nil regardless of input' do
      expect(integration.execute({})).to be_nil
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
      it 'returns an empty array' do
        expect(described_class.supported_events).to eq([])
      end
    end
  end
end
