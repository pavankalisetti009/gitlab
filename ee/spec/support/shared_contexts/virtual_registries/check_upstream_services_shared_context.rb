# frozen_string_literal: true

RSpec.shared_context 'for check upstream service for maven packages' do
  def stub_upstream_request(upstream, status: 200, raise_error: false)
    request = stub_request(:head, upstream.url_for(path)).with(headers: upstream.headers)

    if raise_error
      request.to_raise(Gitlab::HTTP::BlockedUrlError)
    else
      request.to_return(status: status, body: 'test')
    end
  end

  def stub_upstream_redirect(upstream, redirect_to:, final_status: 200, redirect_status: 302)
    # Initial request returns redirect
    stub_request(:head, upstream.url_for(path))
      .with(headers: upstream.headers)
      .to_return(status: redirect_status, headers: { 'Location' => redirect_to })

    # Follow-up request to redirect target
    stub_request(:head, redirect_to)
      .with(headers: upstream.headers)
      .to_return(status: final_status, body: 'test')
  end

  def stub_upstream_chained_redirects(upstream, redirect_chain:, final_status: 200)
    # First request
    stub_request(:head, upstream.url_for(path))
      .with(headers: upstream.headers)
      .to_return(status: 302, headers: { 'Location' => redirect_chain.first })

    # Intermediate redirects
    redirect_chain.each_cons(2) do |current_url, next_url|
      stub_request(:head, current_url)
        .with(headers: upstream.headers)
        .to_return(status: 302, headers: { 'Location' => next_url })
    end

    # Final request
    stub_request(:head, redirect_chain.last)
      .with(headers: upstream.headers)
      .to_return(status: final_status, body: 'test')
  end
end

RSpec.shared_context 'for check upstream service for container images' do
  def stub_upstream_request(upstream, status: 200, raise_error: false, scope: 'repository:test:pull')
    url = upstream.url_for(path)

    # Step 1: Auth discovery - HEAD request returns 401 with WWW-Authenticate header
    stub_request(:head, url)
    .to_return(
      status: 401,
      headers: {
        'www-authenticate' => 'Bearer realm="https://auth.example.com/token",service="registry.example.com",scope="repository:test:pull"'
      }
    )

    # Step 2: Token exchange - GET request to auth service returns bearer token
    stub_request(:get, "https://auth.example.com/token")
      .with(query: { "service" => "registry.example.com", "scope" => scope })
      .to_return(
        status: 200,
        body: '{"token": "fake_bearer_token_123"}'
      )

    # Step 3: Authenticated request - HEAD request with bearer token
    expected_headers = upstream.headers(path).merge(VirtualRegistries::Container::Upstream::REGISTRY_ACCEPT_HEADERS)
    request = stub_request(:head, url).with(headers: expected_headers)

    if raise_error
      request.to_raise(Gitlab::HTTP::BlockedUrlError)
    else
      request.to_return(status: status, body: 'test')
    end
  end
end
