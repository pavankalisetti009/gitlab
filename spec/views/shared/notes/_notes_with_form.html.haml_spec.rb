# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'shared/notes/_notes_with_form', feature_category: :team_planning do
  let(:project) { create(:project, :repository) }
  let(:issue) { create(:issue, project: project) }
  let(:user) { create(:user) }

  before do
    assign(:project, project)
    assign(:issue, issue)
    allow(view).to receive(:can_create_note?).and_return(false)
    allow(view).to receive(:current_user).and_return(nil)
    allow(view).to receive(:autocomplete).and_return(false)
    allow(view).to receive(:diff_view).and_return(:inline)
    allow(view).to receive(:initial_notes_data).and_return({})
  end

  context 'when user is not signed in' do
    context 'when signup is enabled' do
      before do
        stub_application_setting(signup_enabled: true)
      end

      it 'shows both register and sign in links' do
        render

        expect(rendered).to have_content('Please register or sign in to comment')
        expect(rendered).to have_link('register')
        expect(rendered).to have_link('sign in')
      end
    end

    context 'when signup is disabled' do
      before do
        stub_application_setting(signup_enabled: false)
      end

      it 'shows only sign in link' do
        render

        expect(rendered).to have_content('Please sign in to comment')
        expect(rendered).not_to have_link('register')
        expect(rendered).to have_link('sign in')
      end
    end
  end

  context 'when user is signed in but cannot create notes' do
    before do
      allow(view).to receive(:current_user).and_return(user)
      allow(view).to receive(:can_create_note?).and_return(false)
    end

    context 'when discussion is locked' do
      before do
        allow(issue).to receive(:discussion_locked?).and_return(true)
      end

      it 'shows discussion locked message' do
        render

        expect(rendered).to have_content('This issue is locked. Only project members can comment.')
        expect(rendered).not_to have_link('register')
        expect(rendered).not_to have_link('sign in')
      end
    end
  end

  context 'when user can create notes' do
    before do
      allow(view).to receive(:current_user).and_return(user)
      allow(view).to receive(:can_create_note?).and_return(true)
    end

    it 'renders the notes form' do
      expect(view).to receive(:render).with('shared/notes/form', view: :inline, supports_autocomplete: false)
      render
    end
  end
end
