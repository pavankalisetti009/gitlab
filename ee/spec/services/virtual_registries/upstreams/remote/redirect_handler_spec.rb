# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Upstreams::Remote::RedirectHandler, feature_category: :virtual_registry do
  let(:headers) { { 'Authorization' => 'Bearer token' } }
  let(:timeout) { 5 }
  let(:redirect_count) { 0 }

  subject(:handler) { described_class.new(headers: headers, timeout: timeout, redirect_count: redirect_count) }

  describe '#redirect?' do
    using RSpec::Parameterized::TableSyntax

    where(:status_code, :expected_result) do
      200 | false
      201 | false
      204 | false
      301 | true
      302 | true
      303 | true
      307 | true
      308 | true
      400 | false
      404 | false
      500 | false
    end

    with_them do
      let(:response) { instance_double(Typhoeus::Response, code: status_code) }

      it { expect(handler.redirect?(response)).to eq(expected_result) }
    end
  end

  describe '#build_follow_request' do
    let(:redirect_url) { 'https://example.com/redirected/path' }
    let(:response) do
      instance_double(
        Typhoeus::Response,
        code: 302,
        headers: { 'Location' => redirect_url }
      )
    end

    context 'when redirect URL is valid external URL' do
      it 'returns a Typhoeus::Request' do
        request = handler.build_follow_request(response) { |_resp, _handler| nil }

        expect(request).to be_a(Typhoeus::Request)
        expect(request.base_url).to eq(redirect_url)
        expect(request.options[:method]).to eq(:head)
        expect(request.options[:followlocation]).to be(false)
        expect(request.options[:timeout]).to eq(timeout)
        expect(request.options[:headers]).to include(headers)
      end

      it 'passes incremented redirect handler to callback' do
        callback_called = false
        next_handler_redirect_count = nil

        request = handler.build_follow_request(response) do |_resp, next_handler|
          callback_called = true
          next_handler_redirect_count = next_handler.send(:redirect_count)
        end

        # Simulate the callback being called
        request.instance_variable_get(:@on_complete).each do |callback|
          callback.call(instance_double(Typhoeus::Response, code: 200))
        end

        expect(callback_called).to be(true)
        expect(next_handler_redirect_count).to eq(1)
      end
    end

    context 'when redirect URL is localhost' do
      let(:redirect_url) { 'http://localhost:3000/internal' }

      it 'returns nil' do
        expect(handler.build_follow_request(response) { |_resp, _handler| nil }).to be_nil
      end
    end

    context 'when redirect URL is loopback address' do
      let(:redirect_url) { 'http://127.0.0.1:3333/internal' }

      it 'returns nil' do
        expect(handler.build_follow_request(response) { |_resp, _handler| nil }).to be_nil
      end
    end

    context 'when redirect URL is IPv6 loopback' do
      let(:redirect_url) { 'http://[::1]:3333/internal' }

      it 'returns nil' do
        expect(handler.build_follow_request(response) { |_resp, _handler| nil }).to be_nil
      end
    end

    context 'when redirect URL is private network address' do
      using RSpec::Parameterized::TableSyntax

      where(:blocked_url) do
        [
          'http://10.0.0.1/internal',
          'http://172.16.0.1/internal',
          'http://192.168.1.1/internal'
        ]
      end

      with_them do
        let(:redirect_url) { blocked_url }

        it 'returns nil' do
          expect(handler.build_follow_request(response) { |_resp, _handler| nil }).to be_nil
        end
      end
    end

    context 'when redirect URL is link-local address (AWS metadata)' do
      let(:redirect_url) { 'http://169.254.169.254/latest/meta-data/' }

      before do
        allow(Gitlab::HTTP_V2::UrlBlocker).to receive(:validate!)
          .with(redirect_url, anything)
          .and_raise(Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError, 'Requests to the link local network are not allowed')
      end

      it 'returns nil' do
        expect(handler.build_follow_request(response) { |_resp, _handler| nil }).to be_nil
      end
    end

    context 'when max redirects exceeded' do
      let(:redirect_count) { described_class::MAX_REDIRECTS }

      it 'returns nil' do
        expect(handler.build_follow_request(response) { |_resp, _handler| nil }).to be_nil
      end
    end

    context 'when redirect count is one less than max' do
      let(:redirect_count) { described_class::MAX_REDIRECTS - 1 }

      it 'returns a request' do
        request = handler.build_follow_request(response) { |_resp, _handler| nil }

        expect(request).to be_a(Typhoeus::Request)
      end
    end

    context 'when Location header is missing' do
      let(:response) do
        instance_double(
          Typhoeus::Response,
          code: 302,
          headers: {}
        )
      end

      it 'returns nil' do
        expect(handler.build_follow_request(response) { |_resp, _handler| nil }).to be_nil
      end
    end

    context 'when headers are nil' do
      let(:response) do
        instance_double(
          Typhoeus::Response,
          code: 302,
          headers: nil
        )
      end

      it 'returns nil' do
        expect(handler.build_follow_request(response) { |_resp, _handler| nil }).to be_nil
      end
    end
  end

  describe 'constants' do
    it 'has MAX_REDIRECTS set to 5' do
      expect(described_class::MAX_REDIRECTS).to eq(5)
    end

    it 'has correct REDIRECT_STATUS_CODES' do
      expect(described_class::REDIRECT_STATUS_CODES).to contain_exactly(301, 302, 303, 307, 308)
    end
  end
end
