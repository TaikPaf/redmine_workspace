# frozen_string_literal: true

module RedmineWorkspace
  # Describes the issue attributes the current user can edit in place, keyed by
  # the CSS class Redmine gives each attribute block on the issue page.
  class InlineFields
    CORE = {
      'status' => 'status_id',
      'priority' => 'priority_id',
      'assigned-to' => 'assigned_to_id',
      'category' => 'category_id',
      'fixed-version' => 'fixed_version_id',
      'start-date' => 'start_date',
      'due-date' => 'due_date',
      'progress' => 'done_ratio',
      'estimated-hours' => 'estimated_hours'
    }.freeze
    SINGLE_VALUE_FORMATS = %w(list user version enumeration).freeze

    attr_reader :issue, :user

    def initialize(issue, user = User.current)
      @issue = issue
      @user = user
    end

    def editable?
      issue.persisted? && issue.attributes_editable?(user)
    end

    def fields
      return {} unless editable?

      result = {}
      CORE.each do |key, attribute|
        next unless issue.safe_attribute?(attribute, user)

        definition = core_definition(attribute)
        result[key] = definition.merge(attribute: attribute) if definition
      end
      issue.editable_custom_field_values(user).each do |value|
        definition = custom_definition(value)
        result["cf_#{value.custom_field.id}"] = definition if definition
      end
      result
    end

    # Translates a field from #fields into attributes for Issue#safe_attributes=.
    def attributes_for(attribute, value)
      if (m = attribute.to_s.match(/\Acustom_field_(\d+)\z/))
        {'custom_field_values' => {m[1] => value}}
      else
        {attribute.to_s => value}
      end
    end

    def applied?(attribute, value)
      if (m = attribute.to_s.match(/\Acustom_field_(\d+)\z/))
        issue.custom_field_value(CustomField.find(m[1])).to_s == value.to_s
      else
        current = issue.send(attribute)
        current = current.to_s if current.is_a?(Date)
        current = current.to_f.to_s if attribute == 'estimated_hours' && current
        expected = attribute == 'estimated_hours' && value.present? ? value.to_f.to_s : value
        current.to_s == expected.to_s
      end
    end

    def allowed_attribute?(attribute)
      CORE.value?(attribute) ? issue.safe_attribute?(attribute, user) : fields.values.any? {|f| f[:attribute] == attribute}
    end

    private

    def core_definition(attribute)
      case attribute
      when 'status_id'
        select(issue.new_statuses_allowed_to(user).map {|s| [s.name, s.id]}, issue.status_id, blank: false)
      when 'priority_id'
        select(IssuePriority.active.map {|p| [p.name, p.id]}, issue.priority_id, blank: false)
      when 'assigned_to_id'
        select(issue.assignable_users.map {|u| [u.name, u.id]}, issue.assigned_to_id, blank: true)
      when 'category_id'
        categories = issue.project.issue_categories.to_a
        return nil if categories.empty?

        select(categories.map {|c| [c.name, c.id]}, issue.category_id, blank: true)
      when 'fixed_version_id'
        versions = issue.assignable_versions.to_a
        return nil if versions.empty?

        select(versions.map {|v| [v.to_s_with_project, v.id]}, issue.fixed_version_id, blank: true)
      when 'start_date', 'due_date'
        return nil if attribute == 'due_date' && issue.dates_derived?
        return nil if attribute == 'start_date' && issue.dates_derived?

        {type: 'date', value: issue.send(attribute)&.to_s, blank: !issue.required_attribute?(attribute, user)}
      when 'done_ratio'
        return nil unless Issue.use_field_for_done_ratio? && !issue.done_ratio_derived?

        select((0..10).map {|i| ["#{i * 10} %", i * 10]}, issue.done_ratio, blank: false)
      when 'estimated_hours'
        {type: 'number', value: issue.estimated_hours, step: 'any', min: 0, blank: !issue.required_attribute?(attribute, user)}
      end
    end

    def custom_definition(custom_value)
      field = custom_value.custom_field
      return nil if field.multiple?

      attribute = "custom_field_#{field.id}"
      blank = !field.is_required?
      case field.field_format
      when 'string', 'link'
        {type: 'text', value: custom_value.value, blank: blank, attribute: attribute}
      when 'int'
        {type: 'number', value: custom_value.value, step: 1, blank: blank, attribute: attribute}
      when 'float'
        {type: 'number', value: custom_value.value, step: 'any', blank: blank, attribute: attribute}
      when 'date'
        {type: 'date', value: custom_value.value, blank: blank, attribute: attribute}
      when 'bool'
        options = [[::I18n.t(:general_text_Yes), '1'], [::I18n.t(:general_text_No), '0']]
        select(options, custom_value.value, blank: blank).merge(attribute: attribute)
      when *SINGLE_VALUE_FORMATS
        select(field.possible_values_options(issue), custom_value.value, blank: blank).merge(attribute: attribute)
      end
    end

    def select(options, value, blank:)
      normalized = options.map {|option| option.is_a?(Array) ? option : [option, option]}.
        reject {|label, _| label.to_s.start_with?('<<')}.
        map {|label, id| [label.to_s, id.to_s]}
      {type: 'select', value: value.to_s, options: normalized, blank: blank}
    end
  end
end
