# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GitlabSubscriptionsUserRole'] do
  it 'exposes all user roles' do
    expect(described_class.values.keys).to contain_exactly(*%w[GUEST PLANNER REPORTER DEVELOPER MAINTAINER OWNER])
  end

  context 'when security manager role is enabled' do
    before do
      allow(Gitlab::Security::SecurityManagerConfig).to receive(:enabled?).and_return(true)
    end

    it 'exposes all user roles with security manager' do
      expect(described_class.values.keys).to include('SECURITY_MANAGER')
    end
  end
end
