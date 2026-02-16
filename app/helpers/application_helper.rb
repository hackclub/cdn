module ApplicationHelper
  def admin_tool(class_name: "", element: "div", **options, &block)
    return unless current_user&.is_admin?
    concat content_tag(element, class: "admin-tool #{class_name}", **options, &block)
  end
end
