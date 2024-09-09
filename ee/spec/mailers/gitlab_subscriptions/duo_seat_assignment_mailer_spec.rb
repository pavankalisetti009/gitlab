# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::DuoSeatAssignmentMailer, feature_category: :seat_cost_management do
  include EmailSpec::Matchers

  let_it_be(:user) { build(:user) }
  let_it_be(:email_subject) { s_('CodeSuggestions|Welcome to GitLab Duo Pro!') }

  describe '#duo_pro_email' do
    subject(:email) { described_class.duo_pro_email(user) }

    it 'sends mail with expected contents' do
      expect(email).to have_subject(email_subject)
      expect(email).to have_body_text(s_('CodeSuggestions|Get started with GitLab Duo Pro today to boost your ' \
        'efficiency and effectiveness by reducing the time required to write and understand code.'))
    end
  end
end
