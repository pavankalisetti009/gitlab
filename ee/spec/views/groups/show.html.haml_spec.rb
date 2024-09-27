# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/show', feature_category: :groups_and_projects do
  before do
    assign(:group, build(:group))
  end

  context 'with Duo Free Access Ending trial alert' do
    it 'renders the alert partial' do
      render

      expect(rendered).to render_template('shared/_duo_free_access_ending_banner')
    end
  end
end
