# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecretDetection::PartnerTokens::BaseClient, feature_category: :secret_detection do
  let(:client) { described_class.new }
  let(:uri) { URI.parse('https://example.com/api') }
  let(:response) { instance_double(Net::HTTPResponse, body: '{"test": "data"}', code: '200') }

  describe '#verify_token' do
    it 'raises NotImplementedError' do
      expect { client.verify_token('test-token') }
        .to raise_error(NotImplementedError, 'Subclasses must implement verify_token')
    end
  end

  describe 'TokenStatus' do
    using RSpec::Parameterized::TableSyntax

    where(:active_value, :is_active, :is_inactive) do
      true  | true  | false
      false | false | true
    end

    with_them do
      let(:status) { described_class::TokenStatus.new(active: active_value) }

      it 'returns expected activity status' do
        expect(status.active?).to eq(is_active)
        expect(status.inactive?).to eq(is_inactive)
      end
    end
  end

  describe '#make_request' do
    subject(:make_request) { client.send(:make_request, uri) }

    context 'when request is successful' do
      before do
        allow(Integrations::Clients::HTTP).to receive(:get).and_return(response)
      end

      it 'returns response' do
        expect(make_request).to eq(response)
      end
    end

    context 'when handling errors' do
      context 'when timeout errors occur' do
        [Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, Gitlab::HTTP_V2::ReadTotalTimeout].each do |error_class|
          context "with #{error_class}" do
            before do
              allow(Integrations::Clients::HTTP).to receive(:get)
                .and_raise(error_class.new('timeout'))
            end

            it 'raises NetworkError' do
              expect { make_request }.to raise_error(described_class::NetworkError, /Request timeout/)
            end
          end
        end
      end

      context 'when connection errors occur' do
        [Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError].each do |error_class|
          context "with #{error_class}" do
            before do
              allow(Integrations::Clients::HTTP).to receive(:get)
                .and_raise(error_class.new('connection failed'))
            end

            it 'raises NetworkError' do
              expect { make_request }.to raise_error(described_class::NetworkError, /Connection error/)
            end
          end
        end
      end

      context 'with Net::HTTPError' do
        before do
          allow(Integrations::Clients::HTTP).to receive(:get)
            .and_raise(Net::HTTPError.new('http error', nil))
        end

        it 'raises NetworkError' do
          expect { make_request }.to raise_error(described_class::NetworkError, /HTTP error/)
        end
      end

      context 'with StandardError' do
        before do
          allow(Integrations::Clients::HTTP).to receive(:get)
            .and_raise(StandardError.new('unexpected'))
        end

        it 'raises NetworkError' do
          expect { make_request }.to raise_error(described_class::NetworkError, /Unexpected error/)
        end
      end
    end

    context 'with POST request' do
      let(:headers) { { 'Content-Type' => 'application/json' } }
      let(:body) { '{"key": "value"}' }

      before do
        allow(Integrations::Clients::HTTP).to receive(:post).and_return(response)
      end

      it 'makes POST request with body and headers' do
        client.send(:make_request, uri, method: :post, headers: headers, body: body)

        expect(Integrations::Clients::HTTP).to have_received(:post)
          .with(uri, body: body, headers: headers)
      end
    end
  end

  describe '#parse_json_response' do
    using RSpec::Parameterized::TableSyntax

    where(:body, :expected) do
      '{"test": "data"}' | { 'test' => 'data' }
      ''                 | {}
      nil                | {}
    end

    with_them do
      let(:response) { instance_double(Net::HTTPResponse, body: body) }

      it 'returns expected result' do
        expect(client.send(:parse_json_response, response)).to eq(expected)
      end
    end

    context 'with invalid JSON' do
      let(:response) { instance_double(Net::HTTPResponse, body: 'invalid{') }

      it 'raises ResponseError' do
        expect { client.send(:parse_json_response, response) }
          .to raise_error(described_class::ResponseError, /Invalid JSON response/)
      end
    end
  end

  describe '#parse_xml_response' do
    context 'with valid XML' do
      let(:response) { instance_double(Net::HTTPResponse, body: '<?xml version="1.0"?><root><test>data</test></root>') }

      it 'parses XML' do
        result = client.send(:parse_xml_response, response)
        expect(result).to be_a(Nokogiri::XML::Document)
        expect(result.xpath('//test').text).to eq('data')
      end
    end

    context 'with empty body' do
      let(:response) { instance_double(Net::HTTPResponse, body: '') }

      it 'returns empty hash' do
        expect(client.send(:parse_xml_response, response).to_s).to eq(Nokogiri::XML('<empty/>').to_s)
      end
    end

    context 'with invalid XML' do
      let(:response) { instance_double(Net::HTTPResponse, body: '<invalid><xml>') }

      it 'raises ResponseError' do
        expect { client.send(:parse_xml_response, response) }
          .to raise_error(described_class::ResponseError, /Invalid XML response/)
      end
    end
  end

  describe 'response helpers' do
    describe '#success_response' do
      it 'creates active TokenStatus with basic metadata' do
        result = client.send(:success_response)

        expect(result).to be_active
        expect(result.metadata[:partner]).to eq('BASE')
        expect(result.metadata[:verified_at]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
      end
    end

    describe '#failure_response' do
      it 'creates inactive TokenStatus with basic metadata' do
        result = client.send(:failure_response)

        expect(result).to be_inactive
        expect(result.metadata[:partner]).to eq('BASE')
        expect(result.metadata[:verified_at]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
      end
    end
  end
end
