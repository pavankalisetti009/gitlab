# frozen_string_literal: true

require "spec_helper"

RSpec.describe Authz::Resource, feature_category: :system_access do
  subject(:resource_authorization) { described_class.new(user, scope) }

  let(:user) { build_stubbed(:user) }
  let(:scope) { Group.none }

  describe "#permitted" do
    subject(:permitted) { resource_authorization.permitted }

    it { expect { permitted }.to raise_error(NotImplementedError) }
  end
end
