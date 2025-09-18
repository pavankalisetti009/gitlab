# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Middleware::JsonValidation, feature_category: :shared do
  let(:app) { double(:app) } # rubocop:disable RSpec/VerifiedDoubles -- stubbed app
  let(:middleware) { described_class.new(app, options) }
  let(:options) { {} }

  let(:env) do
    {
      'REQUEST_METHOD' => 'POST',
      'CONTENT_TYPE' => content_type,
      'PATH_INFO' => '/api/v4/projects',
      'rack.input' => StringIO.new(body)
    }
  end

  let(:content_type) { 'application/json' }
  let(:body) { '{"key": "value"}' }

  before do
    allow(app).to receive(:call).and_return([200, {}, ['OK']])
  end

  describe '#initialize' do
    it 'merges custom options with defaults' do
      custom_options = { max_depth: 10, mode: :logging, max_json_size_bytes: 30.megabytes }
      middleware = described_class.new(app, custom_options)

      expect(middleware.instance_variable_get(:@options)).to include(
        max_depth: 10,
        max_array_size: 1000,
        max_hash_size: 1000,
        max_total_elements: 10000,
        max_json_size_bytes: 30.megabytes,
        mode: :logging
      )
    end
  end

  describe '#call' do
    context 'when mode is disabled' do
      let(:options) { { mode: :disabled } }

      it 'passes through without validation' do
        expect(app).to receive(:call).with(env)
        expect(::Gitlab::Json::StreamValidator).not_to receive(:new)

        middleware.call(env)
      end
    end

    context 'when request is not JSON' do
      let(:content_type) { 'text/html' }

      it 'passes through without validation' do
        expect(app).to receive(:call).with(env)
        expect(::Gitlab::Json::StreamValidator).not_to receive(:new)

        middleware.call(env)
      end
    end

    context 'with different JSON content types' do
      shared_examples 'validates JSON content type' do
        it 'validates the request' do
          validator = instance_double(::Gitlab::Json::StreamValidator)
          expect(::Gitlab::Json::StreamValidator).to receive(:new).and_return(validator)
          expect(::Oj).to receive(:sc_parse).with(validator, body)
          expect(app).to receive(:call).with(env)

          middleware.call(env)
        end
      end

      context 'with application/json' do
        let(:content_type) { 'application/json' }

        it_behaves_like 'validates JSON content type'
      end

      context 'with application/json; charset=utf-8' do
        let(:content_type) { 'application/json; charset=utf-8' }

        it_behaves_like 'validates JSON content type'
      end

      context 'with application/vnd.git-lfs+json' do
        let(:content_type) { 'application/vnd.git-lfs+json' }

        it_behaves_like 'validates JSON content type'
      end

      context 'with APPLICATION/JSON (uppercase)' do
        let(:content_type) { 'APPLICATION/JSON' }

        it_behaves_like 'validates JSON content type'
      end
    end

    context 'with empty body' do
      let(:body) { '' }

      it 'passes through without validation' do
        expect(app).to receive(:call).with(env)
        expect(::Oj).not_to receive(:sc_parse)

        middleware.call(env)
      end
    end

    context 'with valid JSON' do
      let(:body) { '{"name": "test", "items": [1, 2, 3]}' }

      it 'validates and passes through' do
        expect(app).to receive(:call).with(env)

        result = middleware.call(env)
        expect(result).to eq([200, {}, ['OK']])
      end

      it 'rewinds the request body after reading' do
        rack_input = StringIO.new(body)
        env['rack.input'] = rack_input

        expect(rack_input).to receive(:read).and_call_original
        expect(rack_input).to receive(:rewind).and_call_original

        middleware.call(env)
      end
    end

    context 'with invalid JSON syntax' do
      let(:body) { '{"invalid": json}' }

      it 'allows invalid JSON to pass through' do
        expect(app).to receive(:call).with(env)

        result = middleware.call(env)
        expect(result).to eq([200, {}, ['OK']])
      end
    end

    context 'when JSON body is too large' do
      let(:options) { { max_json_size_bytes: 10 } }
      let(:body) { '{"key": "very long value"}' }

      context 'in enforced mode' do
        let(:options) { { max_json_size_bytes: 10, mode: :enforced } }

        it 'returns 400 error' do
          result = middleware.call(env)

          expect(result[0]).to eq(400)
          expect(result[1]).to eq({ 'Content-Type' => 'application/json' })

          response_body = Gitlab::Json.parse(result[2].first)
          expect(response_body['error']).to include('JSON body too large')
        end

        it 'logs the error' do
          expect(Gitlab::AppLogger).to receive(:warn).with(
            hash_including(
              class_name: 'Gitlab::Middleware::JsonValidation',
              path: '/api/v4/projects',
              message: a_string_including('JSON body too large'),
              status: 400
            )
          )

          middleware.call(env)
        end
      end

      context 'in logging mode' do
        let(:options) { { max_json_size_bytes: 10, mode: :logging } }

        it 'logs error but allows request to continue' do
          expect(Gitlab::AppLogger).to receive(:warn)
          expect(app).to receive(:call).with(env)

          result = middleware.call(env)
          expect(result).to eq([200, {}, ['OK']])
        end
      end
    end

    context 'when JSON exceeds depth limit' do
      let(:options) { { max_depth: 2, mode: :enforced } }
      let(:body) { '{"a": {"b": {"c": "too deep"}}}' }

      it 'returns 400 error with depth message' do
        result = middleware.call(env)

        expect(result[0]).to eq(400)
        response_body = Gitlab::Json.parse(result[2].first)
        expect(response_body['error']).to eq('Parameters nested too deeply')
      end

      it 'logs the depth limit error' do
        expect(Gitlab::AppLogger).to receive(:warn).with(
          hash_including(
            class_name: 'Gitlab::Middleware::JsonValidation',
            message: a_string_including('depth')
          )
        )

        middleware.call(env)
      end
    end

    context 'when JSON exceeds array size limit' do
      let(:options) { { max_array_size: 2, mode: :enforced } }
      let(:body) { '{"items": [1, 2, 3]}' }

      it 'returns 400 error with array size message' do
        result = middleware.call(env)

        expect(result[0]).to eq(400)
        response_body = Gitlab::Json.parse(result[2].first)
        expect(response_body['error']).to eq('Array parameter too large')
      end
    end

    context 'when JSON exceeds hash size limit' do
      let(:options) { { max_hash_size: 2, mode: :enforced } }
      let(:body) { '{"a": 1, "b": 2, "c": 3}' }

      it 'returns 400 error with hash size message' do
        result = middleware.call(env)

        expect(result[0]).to eq(400)
        response_body = Gitlab::Json.parse(result[2].first)
        expect(response_body['error']).to eq('Hash parameter too large')
      end

      it 'logs the hash size limit error' do
        expect(Gitlab::AppLogger).to receive(:warn).with(
          hash_including(
            class_name: 'Gitlab::Middleware::JsonValidation',
            message: a_string_including('Hash size exceeds limit')
          )
        )

        middleware.call(env)
      end
    end

    context 'when JSON exceeds total elements limit' do
      let(:options) { { max_total_elements: 3, mode: :enforced } }
      let(:body) { '{"a": 1, "b": 2, "c": 3, "d": 4}' }

      it 'returns 400 error with element count message' do
        result = middleware.call(env)

        expect(result[0]).to eq(400)
        response_body = Gitlab::Json.parse(result[2].first)
        expect(response_body['error']).to eq('Too many total parameters')
      end
    end

    context 'in logging mode with validation errors' do
      let(:options) { { max_depth: 1, mode: :logging } }
      let(:body) { '{"a": {"b": "nested"}}' }

      it 'logs error but continues processing' do
        expect(Gitlab::AppLogger).to receive(:warn)
        expect(app).to receive(:call).with(env)

        result = middleware.call(env)
        expect(result).to eq([200, {}, ['OK']])
      end
    end

    context 'with instrumentation' do
      let(:options) { { max_depth: 1, mode: :enforced } }
      let(:body) { '{"a": {"b": "nested"}}' }

      it 'adds instrumentation data' do
        expect(::Gitlab::InstrumentationHelper).to receive(:add_instrumentation_data).with(
          hash_including(
            max_depth: 1,
            mode: :enforced,
            path: '/api/v4/projects',
            message: a_string_including('depth')
          )
        )

        middleware.call(env)
      end
    end
  end
end
