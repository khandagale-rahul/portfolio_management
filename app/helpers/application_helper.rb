module ApplicationHelper
  def current_user
    Current.session&.user
  end

  def sortable(column, title = nil)
    title ||= column.titleize
    direction = column == params[:sort] && params[:direction] == "asc" ? "desc" : "asc"
    icon = ""

    if column == params[:sort]
      icon = params[:direction] == "asc" ? " <i class='bi bi-arrow-up'></i>" : " <i class='bi bi-arrow-down'></i>"
    end

    link_to "#{title}#{icon}".html_safe, { sort: column, direction: direction }, class: "text-decoration-none text-dark"
  end
end
