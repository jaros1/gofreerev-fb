class AboutController < ApplicationController
  def index
    @sections = %w(about betatest cookies disclaimer )
  end
end
