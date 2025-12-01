# frozen_string_literal: true

RSpec.shared_context 'with elasticsearch connection options' do
  let(:connection_options) do
    {
      url: [
        { scheme: "http", host: "localhost", port: 9200 },
        { scheme: "http", host: "localhost", port: 9200, user: 'dummy', password: 'pass123' }
      ]
    }
  end

  let(:expected_elasticsearch_urls) do
    ['http://localhost:9200/', 'http://dummy:pass123@localhost:9200/']
  end

  let(:adapter) do
    ::ActiveContext::Databases::Elasticsearch::Adapter.new(connection, options: connection_options)
  end

  before do
    connection.update!(
      adapter_class: adapter.class,
      options: connection_options
    )
  end
end

RSpec.shared_context 'with opensearch connection options' do
  let(:adapter_name) { 'opensearch' }
  let(:connection_options) do
    {
      url: [{ scheme: "https", host: "search-test.us-east-1.es.amazonaws.com", port: 443 }],
      aws: true,
      aws_region: 'us-east-1',
      aws_access_key: '********************',
      aws_secret_access_key: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
      client_request_timeout: 60
    }
  end

  let(:expected_opensearch_connection) do
    connection_options.stringify_keys.merge(
      'url' => connection_options[:url].map { |u| "#{u[:scheme]}://#{u[:host]}/" }
    )
  end

  let(:adapter) do
    ::ActiveContext::Databases::Opensearch::Adapter.new(connection, options: connection_options)
  end

  before do
    connection.update!(
      adapter_class: adapter.class,
      options: connection_options
    )
  end
end

RSpec.shared_context 'with plain string URL connection options' do
  let(:connection_options) { { url: ['http://localhost:9200', 'http://localhost:9201'] } }
  let(:expected_connection_hash) { connection_options.stringify_keys }
  let(:adapter) do
    ::ActiveContext::Databases::Elasticsearch::Adapter.new(connection, options: connection_options)
  end

  before do
    connection.update!(
      adapter_class: adapter.class,
      options: connection_options
    )
  end
end
