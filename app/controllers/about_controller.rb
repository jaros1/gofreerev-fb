class AboutController < ApplicationController
  def index
    @sections = %w(about betatest cookies privacy disclaimer )
  end
end
