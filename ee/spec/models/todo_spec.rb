# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Todo, feature_category: :team_planning do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, developers: current_user) }
  let_it_be(:epic) { create(:epic, group: group) }

  describe '#target_url' do
    subject { todo.target_url }

    context 'when the todo is coming from an epic' do
      context 'when coming from the epic itself' do
        let_it_be(:todo) { create(:todo, project: nil, group: group, user: current_user, target: epic) }

        it 'returns the work item web path' do
          is_expected.to eq("http://localhost/groups/#{group.full_path}/-/epics/#{epic.iid}")
        end
      end

      context 'when coming from a note on the epic' do
        let_it_be(:note) { create(:note, noteable: epic) }
        let_it_be(:todo) { create(:todo, project: nil, group: group, user: current_user, note: note, target: epic) }

        it 'returns the work item web path with an anchor to the note' do
          is_expected.to eq("http://localhost/groups/#{group.full_path}/-/epics/#{epic.iid}#note_#{note.id}")
        end
      end
    end
  end
end
