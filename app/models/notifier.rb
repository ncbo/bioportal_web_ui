class Notifier < ActionMailer::Base
  def feedback(name, email, comment, location = "")
    @name = name
    @email = email
    @comment = comment
    @location = location

    mail(:to => "#{$SUPPORT_EMAIL}, #{email}",
         :from => "#{$SUPPORT_EMAIL}",
         :subject => "[#{$SITE}] Feedback from #{name}")
  end
end
