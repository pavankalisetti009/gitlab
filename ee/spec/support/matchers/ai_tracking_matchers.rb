# frozen_string_literal: true

# Examples
# is_expected.to have_ai_event_registered(troubleshoot_job: 7)
# is_expected.to have_ai_event_registered(troubleshoot_job: 7).with_no_transformations
# is_expected.to have_ai_event_registered(troubleshoot_job: 7)
#   .with_transformation({job: job} => {pipeline_id: job.pipeline_id})
RSpec::Matchers.define :have_ai_event_registered do |event_name_and_id|
  event_name, event_id = *event_name_and_id.first

  chain(:with_transformation) do |transformation_map|
    @sample_context, @expected_transformed_context = *transformation_map.first.map(&:with_indifferent_access)
  end

  chain(:with_no_transformations) do
    @sample_context = nil
    @expected_transformed_context = nil
  end

  match do |registry|
    expect(registry.registered_events[event_name]).to eq(event_id)

    if @sample_context && @expected_transformed_context
      transformations = registry.registered_transformations(event_name)
      @actual_transformed_context = transformations.inject({}.with_indifferent_access) do |acc, block|
        acc.merge(block.call(@sample_context.merge(acc)))
      end

      expect(@actual_transformed_context).to eq(@expected_transformed_context)
    else
      expect(registry.registered_transformations(event_name)).to be_empty
    end
  end

  failure_message do |registry|
    message = "Expected #{registry} to have event #{event_name}##{event_id} to be registered, but"
    message += if registry.registered_events[event_name] == event_id && @expected_transformed_context
                 <<-MSG
 event transformation didn't match.
   Expected transformed context: #{@expected_transformed_context.inspect}
   Actual transformed context: #{@actual_transformed_context.inspect}.
                 MSG
               else
                 " no event with such name and ID was found."
               end

    message
  end
end
