module AuthHelper

  def log_in_link (provider)
    link_to t(".log_in_link_text_#{provider}"), "/auth/#{provider}"
  end

  def log_out_link (provider)
    "log out off #{provider}"
  end

end
