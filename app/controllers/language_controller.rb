class LanguageController < ApplicationController

    # set locale to the language selected by the user
    def set_locale_language
        language = params[:language].strip.downcase.to_sym
        supported_languages = I18n.available_locales

        if language
            if supported_languages.include?(language)
                 cookies.permanent[:locale] = language
            else
                # in case we want to show a message if the language is not available
                flash.now[:notice] = t('language.translation_not_available', language: language)
                logger.error flash.now[:notice]
            end
        end

        redirect_to request.referer || root_path
    end

end
