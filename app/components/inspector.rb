# frozen_string_literal: true

class Components::Inspector < Components::Base
  def initialize(object:)
    @object = object
  end

  def view_template
    admin_tool do
      details class: "inspector" do
        summary { record_id }
        pre class: "inspector-content" do
          unless @object.nil?
            raw safe(ap @object)
          else
            plain "nil"
          end
        end
      end
    end
  end

  private

  def record_id
    "#{@object.class.name} #{@object&.try(:public_id) || @object&.id}"
  end
end
