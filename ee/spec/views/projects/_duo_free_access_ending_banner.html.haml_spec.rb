# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'projects/_duo_free_access_ending_banner.html.haml', feature_category: :acquisition do
  let(:project) { build(:project, group: group) }

  before do
    allow(view).to receive(:project).and_return(project)
  end

  context 'when project is not personal' do
    let(:group) { build(:group) }

    it 'renders the template' do
      render

      expect(rendered).to render_template('projects/_duo_free_access_ending_banner')
    end
  end

  context 'when project is personal' do
    let(:group) { nil }

    it 'does not render anything' do
      expect { render }.to raise_error(TypeError)
    end
  end
end
