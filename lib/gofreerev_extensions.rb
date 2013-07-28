module GofreerevExtensions

  # text translation: http://guides.rubyonrails.org/i18n.html
  # this extension adds usertype (fb, gp etc) first in scope.
  # first lookup with usertype first in scope
  # second lookup without usertype in scope only if text not found in first lookup with usertype in scope.
  private
  def my_translate (key, options = {})
    # puts "my_tranlate"
    scope = options[:scope]
    if scope
      scope = scope.to_s if scope.class.name == 'Symbol'
      scope = scope.split('.') if scope.class.name == 'String'
      return translate(key, options) unless scope.class.name == 'Array'
      usertype_in_scope = scope.find { |s| s.to_s.downcase == session[:usertype] }
      options[:scope] = scope = [ session[:usertype] ] + scope unless usertype_in_scope
    else
      options[:scope] = scope = [ session[:usertype] ]
    end
    # first lookup with usertype in scope
    options[:raise] = I18n::MissingTranslationData
    # puts "my_translate: first lookup: key = #{key}, scope = " + scope.join(',')
    begin
      translate(key, options)
    rescue I18n::MissingTranslationData
      # puts "I18n::MissingTranslationData. e = #{e.to_s}"
      # second lookup without usertype in scope
      options.delete(:raise)
      options[:scope] = scope.delete_if { |s| s.to_s.downcase == session[:usertype] }
      # repeat translate without usertype in scope
      # puts "my_translate: second lookup: key = #{key}, scope = " + scope.join(',')
      return translate(key, options)
    end
  end
  alias :my_t :my_translate

end # GofreerevExtensions