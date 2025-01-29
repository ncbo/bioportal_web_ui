class Display::AlertComponent < ViewComponent::Base
    def initialize(id: nil, message: nil, closable: true, type: "info", auto_close_delay: nil, button: nil)
        @message = message
        @closable = closable
        @type = type
        @auto_close_delay =  auto_close_delay
        @button = button
        @id = id
    end

    def closable?
        @closable
    end

    def message
        @message
    end

    def alert_type_class
        case @type
        when "info"
            "alert-info-type"
        when "warning"
            "alert-warning-type"
        when "danger"
            "alert-danger-type"
        when "success"
            "alert-success-type"
        end
    end

    def alert_icon
        case @type
        when "info"
            "info.svg"
        when "warning"
            "warning.svg"
        when "danger"
            "danger.svg"
        when "success"
            "success.svg"
        end
    end

    def auto_close?
        !@auto_close_delay.nil?
    end

    def button
        @button
    end
end