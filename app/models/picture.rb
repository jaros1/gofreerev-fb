PICTURE_STORE_LEVELS = 5 # ((26+10) ** 2) ** PICTURE_STORE_LEVELS combinations
PICTURE_IMAGE_TYPES = %w(jpg jpeg gif png bmp) # supported image types - must be supported for all API's with picture upload

PICTURE_OS_ROOT = Rails.root.join('public', 'images').to_s
PICTURE_TEMP_OS_ROOT = "#{PICTURE_OS_ROOT}/temp"
PICTURE_PERM_OS_ROOT = "#{PICTURE_OS_ROOT}/perm"

PICTURE_URL_ROOT = "#{SITE_URL}/images".gsub('//images', '/images')
PICTURE_TEMP_URL_ROOT = "#{PICTURE_URL_ROOT}/temp"
PICTURE_PERM_URL_ROOT = "#{PICTURE_URL_ROOT}/perm"


class Picture < ActiveRecord::Base

  # picture store helpers
  # a) download profile pictures to /images/perm/
  # b) move file upload images to /images/temp/ or /images/perm/
  # c) replaced old profile image in /images/perm/ with old or new image type
  # d) move picture from temp to perm store if selected store is :api
  # e) delete pictures
  # f) cleanup empty folders

  # picture urls are:
  # 1) "#{SITE_URL}/images/temp/#{imagename}.#{imagetype}"         - temporary stored for upload to API
  # 2) "#{SITE_URL}/images/perm/#{path}/#{imagename}.#{imagetype}" - stored locally on this server
  # 3) other                                                       - link to profile picture or image at API

  # new rel_path helpers

  private
  def self.string
    String.generate_random_string(PICTURE_STORE_LEVELS*2).downcase
  end
  def self.check_image_type (image_type)
    raise ImageNotFound.new('') if image_type.to_s == ""
    raise InvalidImageType.new(image_type) unless PICTURE_IMAGE_TYPES.index(image_type)
  end
  def self.new_unchecked_temp_rel_path (image_type)
    Picture.check_image_type(image_type)
    "temp/#{Picture.string}.#{image_type}"
  end
  def self.new_unchecked_perm_path (image_type)
    Picture.check_image_type(image_type)
    path = Picture.string.scan(/.{2}/).join('/')
    "perm/#{path}.#{image_type}"
  end
  public
  def self.new_temp_rel_path (image_type)
    loop do
      rel_path = Picture.new_unchecked_temp_rel_path(image_type)
      filename = "#{PICTURE_OS_ROOT}/#{rel_path}"
      puts "filename = #{filename}"
      return rel_path unless File.exist? filename
    end
  end
  def self.new_perm_rel_path (image_type)
    loop do
      rel_path = Picture.new_unchecked_perm_path(image_type)
      filename = "#{PICTURE_OS_ROOT}/#{rel_path}"
      puts "filename = #{filename}"
      return rel_path unless File.exist? filename
    end
  end

  def self.find_picture_store (login_users)
    providers = login_users.collect { |u| u.provider }
    # :local picture store?
    login_users.each do |login_user|
      next unless API_GIFT_PICTURE_STORE[login_user.provider] == :local
      return :local if login_user.post_on_wall_allowed?
    end
    # :api picture store?
    login_users.each do |login_user|
      next unless API_GIFT_PICTURE_STORE[login_user.provider] == :api
      return :api if login_user.post_on_wall_allowed?
    end
    # fallback option when :local or :api picture store was not available
    return :local if API_GIFT_PICTURE_STORE[:fallback] == :local
    # no fallback - could be a readonly API as google+ - image upload is not allowed
    nil
  end

  def self.new_temp_or_perm_rel_path (login_users, image_type)
    case Picture.find_picture_store(login_users)
      when :local then Picture.new_perm_rel_path image_type
      when :api then Picture.new_term_rel_path image_type
      else nil # error - no picture store - could be google+ - image upload is not allowed
    end
  end # self.new_temp_or_perm_rel_path


  # test helpers

  def self.temp_app_url? (url)
    url = url.to_s
    return false if url == ""
    (url.first(PICTURE_TEMP_URL_ROOT.length) == PICTURE_TEMP_URL_ROOT)
  end
  def self.perm_app_url? (url)
    url = url.to_s
    return false if url == ""
    (url.first(PICTURE_PERM_URL_ROOT.length) == PICTURE_PERM_URL_ROOT)
  end
  def self.app_url? (url)
    url = url.to_s
    return false if url == ""
    (Picture.temp_app_url?(url) or Picture.perm_app_url?(url))
  end
  def self.api_url? (url)
    url = url.to_s
    return false if url == ""
    !Picture.app_url?(url)
  end
  def self.app_rel_path? (rel_path)
    rel_path = rel_path.to_s
    return false if rel_path == ""
    return false unless %w(temp/ perm/).index(rel_path.first(5))
    return false if rel_path.index('..')
    true
  end
  def self.app_full_os_path? (full_os_path)
    full_os_path = full_os_path.to_s
    return false if full_os_path == ''
    return false if full_os_path.index('..')
    ( full_os_path.first(PICTURE_TEMP_OS_ROOT.size) == PICTURE_TEMP_OS_ROOT or
      full_os_path.first(PICTURE_PERM_OS_ROOT.size) == PICTURE_PERM_OS_ROOT )
  end


  # convert helpers

  private
  def self.rel_path_from_url (url)
    url = url.to_s
    raise InvalidCall.new('System error. Expected app url') unless Picture.app_url?(url)
    url.from(PICTURE_URL_ROOT.size+1)
  end
  def self.full_os_path_from_rel_path (rel_path)
    "#{PICTURE_OS_ROOT}/#{rel_path}"
  end
  def self.url_from_rel_path (rel_path)
    "#{PICTURE_URL_ROOT}/#{rel_path}"
  end
  def self.rel_path_from_full_os_path(full_os_path)
    full_os_path = full_os_path.to_s
    raise InvalidCall.new('System error. Extected full_os_path') unless Picture.app_full_os_path?(full_os_path)
    full_os_path.from(PICTURE_OS_ROOT.size+1)
  end

  # check :url, :rel_path, :full_os_path option for app picture
  private
  def self.check_app_options (app_options)
    msg1 = 'System error. Expected options Hash with :url, :rel_path or :full_os_path'
    if app_options.class != Hash or app_options.size == 0 or  app_options.size > 3
      raise InvalidCall.new(msg1)
    end
    if (app_options.keys - [:url, :rel_path, :full_os_path]).size > 0
      raise InvalidCall.new(msg1)
    end
    url, rel_path, full_os_path = app_options[:url], app_options[:rel_path], app_options[:full_os_path]
    case
      when url
        raise InvalidCall.new('System error. Invalid :url option. Expected an app url') unless Picture.app_url?(url)
        url2 = url
        rel_path2 = Picture.rel_path_from_url(url)
        full_os_path2 = Picture.full_os_path_from_rel_path(rel_path2)
      when rel_path
        raise InvalidCall.new('System error. Invalid :rel_path option. Expected an rel_path to temp or perm images') unless Picture.app_rel_path?(rel_path)
        rel_path2 = rel_path
        url2 = Picture.url_from_rel_path(rel_path)
        full_os_path2 = Picture.full_os_path_from_rel_path(rel_path)
      when full_os_path
        raise InvalidCall.new('System error. Invalid :full_os_path option. Expected full path to temp or perm images') unless Picture.app_full_os_path?(full_os_path)
        full_os_path2 = full_os_path
        rel_path2 = Picture.rel_path_from_full_os_path(full_os_path)
        url2 = Picture.url_from_rel_path(rel_path2)
    end # case
    raise InvalidCall.new("System error. Invalid :url option. Found #{url}. Extected #{url2}") if url and url != url2
    raise InvalidCall.new("System error. Invalid :rel_path option. Found #{rel_path}. Extected #{rel_path2}") if rel_path and rel_path != rel_path2
    raise InvalidCall.new("System error. Invalid :full_os_path options. Found #{full_os_path}. Extected #{full_os_path2}") if full_os_path and full_os_path != full_os_path2
    # app_options ok and all three options are now initialized
    app_options[:url], app_options[:rel_path], app_options[:full_os_path] = url2, rel_path2, full_os_path2
  end # check_options

  public
  def self.rel_path (options)
    Picture.check_app_options(options)
    options[:rel_path]
  end
  def self.full_os_path (options)
    Picture.check_app_options(options)
    options[:full_os_path]
  end
  def self.url(options)
    Picture.check_app_options(options)
    options[:url]
  end

  def self.find_picture_type (fullpath_or_url)
    image_type = FastImage.type(fullpath_or_url.to_s).to_s
    Picture.check_image_type(image_type)
    image_type
  end

  # create parent dir for perm picture before move or copy new picture
  def self.create_parent_dirs (options)
    Picture.check_app_options(options)
    url, rel_path = options[:url], options[:rel_path]
    return unless Picture.perm_app_url? url
    # find parent dir
    rel_path = rel_path.split('/')[0..-2].join('/')
    full_os_path = Picture.full_os_path :rel_path => rel_path
    # create parent dirs
    FileUtils.mkdir_p full_os_path
  end # self.create_parent_dirs

  # delete picture if local app url - for example delete gift with picture or after changing profile picture store to :api
  def self.delete_if_app_url(url)
    return nil if url.to_s == ""
    Picture.delete(:url => url) if Picture.app_url?(url)
  end

  # delete picture including empty parent folders
  def self.delete (options)
    Picture.check_app_options(options)
    url, full_os_path = options[:url], options[:full_os_path]
    if !File.exist?(full_os_path)
      logger.warn2 "Picture was not found. Filename = #{full_os_path}"
      return
    end
    # delete picture
    File.delete(full_os_path)
    return if Picture.temp_app_url?(url)
    # cleanup empty parent folders
    Picture.delete_empty_parent_dirs :full_os_path => full_os_path
  end # delete

  # used after picture delete to remove empty parent dirs
  def self.delete_empty_parent_dirs (options)
    Picture.check_app_options(options)
    url, rel_path, full_os_path = options[:url], options[:rel_path], options[:full_os_path]
    msg = 'Expected :url, :rel_path or :perm_perm to deleted picture in perm'
    raise InvalidCall.new(msg) unless Picture.perm_app_url?(url)
    raise InvalidCall.new(msg) if File.exists?(full_os_path)
    # cleanup unused parent folders
    loop do
      rel_path = rel_path.split('/')[0..-2].join('/')
      return unless rel_path.index('/') # never delete temp or perm root folder
      dir_full_path = Picture.full_os_path :rel_path => rel_path
      return unless (Dir.entries(dir_full_path) - %w{ . .. }).empty? # only delete empty parent folders
      FileUtils.rmdir  dir_full_path
    end
  end

  # cleanup empty folders under PICTURE_PERM_OS_ROOT (Picture.delete should remove empty parent folders)
  def self.delete_empty_sub_dirs (options = {})
    options[:full_os_path] = PICTURE_PERM_OS_ROOT if options == {}
    Picture.check_app_options(options)
    url, full_os_path = options[:url], options[:full_os_path]
    if !Picture.perm_app_url?(url)
      logger.error2 "Invalid root path. Options = #{options}"
      return 1
    end
    if !File.exist?(full_os_path)
      logger.error2 "File does not exists. file = #{full_os_path}"
      return 1
    end
    return 1 if !File.directory?(full_os_path)
    # check dir - recursive - delete empty dirs - count number of files including sub dirs
    no_files = 0
    Dir.entries(full_os_path).each do |dir|
      next if %w(. ..).index(dir)
      new_full_os_path = "#{full_os_path}/#{dir}"
      no_files += Picture.delete_empty_sub_dirs(:full_os_path => new_full_os_path) # recursive call
    end
    return no_files if full_os_path == PICTURE_PERM_OS_ROOT
    FileUtils.rmdir full_os_path if no_files == 0
    no_files == 0 ? 0 : no_files + 1
  end # delete_empty_dirs


  # temp dir helpers - temp dirs are used when downloading pictures
  
  def self.create_tmp_dir (options)
    Picture.check_app_options(options)
    url, rel_path, full_os_path = options[:url], options[:rel_path], options[:full_os_path]
    msg = 'Expected :url, :rel_path or :perm_perm to picture in perm'
    raise InvalidCall.new(msg) unless Picture.perm_app_url?(url)
    # create temp dir for picture download
    tmp_dir_rel_path = "#{rel_path}.tmp"
    tmp_dir_full_os_path = Picture.full_os_path :rel_path => tmp_dir_rel_path
    FileUtils.mkdir_p tmp_dir_full_os_path
    tmp_dir_full_os_path
  end
  
  def self.delete_tmp_dir (options)
    Picture.check_app_options(options)
    url, full_os_path = options[:url], options[:full_os_path]
    msg = 'Expected :url, :rel_path or :perm_perm to picture in perm'
    raise InvalidCall.new(msg) unless Picture.perm_app_url?(url)
    stdout, stderr, status = User.open4("rm *", full_os_path)
    logger.debug2 "rm: stdout = #{stdout}, stderr = #{stderr}, status = #{status} (#{status.class})"
    FileUtils.rmdir full_os_path
    Picture.delete_empty_parent_dirs :full_os_path => full_os_path
  end

end