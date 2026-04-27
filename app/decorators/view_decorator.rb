class ViewDecorator
  attr_reader :view, :view_context

  def initialize(view, view_context)
    @view, @view_context = view, view_context
  end

  def description
    latest_submission = view.explore.latest_submission
    latest_submission.nil? ? "No description provided" : latest_submission.description
  end
end