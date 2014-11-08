class OpenGraphLink < ActiveRecord::Base

  # create_table "open_graphs", force: true do |t|
  #   t.text     "url"
  #   t.string   "title"
  #   t.string   "description"
  #   t.text     "image"
  #   t.datetime "created_at"
  #   t.datetime "updated_at"
  #   t.datetime "last_usage_at"
  # end

  # cache Open Graph tags (http://ogp.me/) for gifts.external_url
  # use embed.ly API (EMBEDLY=true) or opengraph_parser gem get open graph meta-tags from html pages (EMBEDLY=false).

  # returns nil if url does not exists or if there are issues with html page
  def self.find_or_create_link (url)
    url = url.to_s
    return nil if url == ""
    return nil unless url =~ /^https?:\/\//
    og = OpenGraphLink.find_by_url(url)
    return og if og and og.updated_at > 1.week.ago
    # todo: check if url exists
    # get open graph meta tags. Embed,ly API or parse html response
    if !og
      og = OpenGraphLink.new
      og.url = url
    end
    if false # EMBEDLY
      # use embed.ly API to parse html page for open graph metatags. free for <5000 API requests per month
      # todo: add error handling
      api_client = Embedly::API.new :key => EMBEDLY_KEY
      response = api_client.oembed :url => url
      og.title       = response[0].title
      og.description = response[0].description
      og.image       = response[0].thumbnail_url
      og.updated_at  = Time.now
    else
      # use opengraph_parser gem
      # todo: add error handling
      response = OpenGraph.new(url)
      og.title = response.title
      og.description = response.description
      og.image = response.images.first
      og.updated_at  = Time.now
    end
    # replace ' with "
    og.title = og.title.gsub("'", '"') if og.title
    og.description = og.description.gsub("'", '"') if og.description
    if og.image.to_s != ''
      filetype = FastImage.type(og.image).to_s
      og.image = nil unless %w(jpg jpeg gif png bmp).index(filetype)
    end
    # save and return record
    og.save!
    og
  end # self.find_or_create_link

end
