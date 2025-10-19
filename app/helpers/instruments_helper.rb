module InstrumentsHelper
  # Display LTP with color-coded arrow based on comparison with previous day LTP
  # Returns HTML-safe string with formatted currency and arrow icon
  def display_ltp(master_instrument)
    return content_tag(:span, number_to_currency(0)) if master_instrument.ltp.blank?

    if master_instrument.previous_day_ltp.present?
      if master_instrument.ltp > master_instrument.previous_day_ltp
        content_tag(:span, class: "text-success") do
          number_to_currency(master_instrument.ltp) +
          content_tag(:i, "", class: "fa fa-arrow-up text-success ms-1")
        end
      elsif master_instrument.ltp < master_instrument.previous_day_ltp
        content_tag(:span, class: "text-danger") do
          number_to_currency(master_instrument.ltp) +
          content_tag(:i, "", class: "fa fa-arrow-down text-danger ms-1")
        end
      else
        content_tag(:span, number_to_currency(master_instrument.ltp))
      end
    else
      content_tag(:span, number_to_currency(master_instrument.ltp))
    end
  end

  # Calculate and display price change as absolute value and percentage
  # Returns HTML-safe string with color-coded change
  # Format: "+5.50 (+2.5%)" or "-3.25 (-1.8%)"
  def display_price_change(master_instrument)
    return content_tag(:span, "—", class: "text-muted") if master_instrument.ltp.blank? || master_instrument.previous_day_ltp.blank?

    change = master_instrument.ltp - master_instrument.previous_day_ltp
    change_percent = (change / master_instrument.previous_day_ltp) * 100

    css_class = if change > 0
                  "text-success"
    elsif change < 0
                  "text-danger"
    else
                  "text-muted"
    end

    formatted_change = change.abs
    formatted_percent = number_with_precision(change_percent.abs, precision: 2)
    sign = change >= 0 ? "+" : "-"

    content_tag(:span, class: css_class) do
      # "#{sign}#{formatted_change} (#{sign}#{formatted_percent}%)"
      "#{sign}#{formatted_percent}%"
    end
  end
end
