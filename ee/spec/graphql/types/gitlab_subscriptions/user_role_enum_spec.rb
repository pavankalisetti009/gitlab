# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GitlabSubscriptionsUserRole'] do
  it 'exposes all user roles' do
    expect(described_class.values.keys).to contain_exactly(*%w[GUEST PLANNER REPORTER SECURITY_MANAGER DEVELOPER
      MAINTAINER OWNER])
  end

  context 'when security manager role is disable', :disable_security_manager do
    it 'exposes all user roles without security manager' do
      expect(described_class.values.keys).not_to include('SECURITY_MANAGER')
    end
  end
end
