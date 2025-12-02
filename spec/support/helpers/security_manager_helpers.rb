# frozen_string_literal: true

module SecurityManagerHelpers
  def with_security_manager_enabled
    allow(Gitlab::Security::SecurityManagerConfig).to receive(:enabled?).and_return(true)
    yield
  ensure
    allow(Gitlab::Security::SecurityManagerConfig).to receive(:enabled?).and_call_original
  end

  def with_security_manager_disabled
    allow(Gitlab::Security::SecurityManagerConfig).to receive(:enabled?).and_return(false)
    yield
  ensure
    allow(Gitlab::Security::SecurityManagerConfig).to receive(:enabled?).and_call_original
  end
end
