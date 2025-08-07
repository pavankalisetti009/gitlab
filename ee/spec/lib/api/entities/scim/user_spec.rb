# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::Scim::User, feature_category: :system_access do
  let(:user) { build(:user) }
  let(:identity) { build(:group_saml_identity, user: user) }

  let(:entity) do
    described_class.new(identity)
  end

  subject(:json_response) { entity.as_json }

  it 'contains the schemas' do
    expect(json_response[:schemas]).to eq(["urn:ietf:params:scim:schemas:core:2.0:User"])
  end

  it 'contains the extern UID' do
    expect(json_response[:id]).to eq(identity.extern_uid)
  end

  it 'contains the active flag' do
    expect(json_response[:active]).to be true
  end

  it 'contains the name' do
    expect(json_response[:name][:formatted]).to eq(user.name)
  end

  it 'contains the first name' do
    expect(json_response[:name][:givenName]).to eq(user.first_name)
  end

  it 'contains the last name' do
    expect(json_response[:name][:familyName]).to eq(user.last_name)
  end

  it 'contains the email' do
    expect(json_response[:emails].first[:value]).to eq(user.email)
  end

  it 'contains the username' do
    expect(json_response[:userName]).to eq(user.username)
  end

  it 'contains the resource type' do
    expect(json_response[:meta][:resourceType]).to eq('User')
  end

  it 'contains the email type' do
    expect(json_response[:emails].first[:type]).to eq('work')
  end

  it 'contains the email primary flag' do
    expect(json_response[:emails].first[:primary]).to be true
  end

  context 'with a SCIM identity' do
    let(:identity) { build(:scim_identity, user: user) }

    it 'contains active false when the identity is not active' do
      identity.active = false

      expect(json_response[:active]).to be false
    end
  end
end
