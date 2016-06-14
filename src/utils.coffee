_ = require("lodash")
config = require("./config")
querystring = require('querystring')
utils = exports

exports.CF_SHARED_CDN = "d3jpl91pxevbkh.cloudfront.net"
exports.OLD_AKAMAI_SHARED_CDN = "cloudinary-a.akamaihd.net"
exports.AKAMAI_SHARED_CDN = "res.cloudinary.com"
exports.SHARED_CDN = exports.AKAMAI_SHARED_CDN

exports.VERSION = "1.3.0"
exports.USER_AGENT = "CloudinaryNodeJS/#{exports.VERSION}"
# Add platform information to the USER_AGENT header
# This is intended for platform information and not individual applications!
exports.userPlatform = ""
exports.getUserAgent = ()->
  if _.isEmpty(utils.userPlatform)
    "#{utils.USER_AGENT}"
  else
    "#{utils.userPlatform} #{utils.USER_AGENT}"

DEFAULT_RESPONSIVE_WIDTH_TRANSFORMATION = {width: "auto", crop: "limit"}
exports.DEFAULT_POSTER_OPTIONS = {format: 'jpg', resource_type: 'video'}
exports.DEFAULT_VIDEO_SOURCE_TYPES = ['webm', 'mp4', 'ogv']


LAYER_KEYWORD_PARAMS =
  font_weight: "normal"
  font_style: "normal"
  text_decoration: "none"
  text_align: null
  stroke: "none"

textStyle = (layer)->
  font_family = layer["font_family"]
  font_size = layer["font_size"]
  keywords = []
  for attr, default_value of LAYER_KEYWORD_PARAMS
    attr_value = layer[attr] || default_value
    keywords.push(attr_value) unless attr_value == default_value
  letter_spacing = layer["letter_spacing"]
  keywords.push("letter_spacing_#{letter_spacing}") if letter_spacing
  line_spacing = layer["line_spacing"]
  keywords.push("line_spacing_#{line_spacing}") if line_spacing
  if font_size || font_family || !_.isEmpty(keywords)
    raise(CloudinaryException, "Must supply font_family for text in overlay/underlay") unless font_family
    raise(CloudinaryException, "Must supply font_size for text in overlay/underlay") unless font_size
    keywords.unshift(font_size)
    keywords.unshift(font_family)
    _.compact(keywords).join("_")

exports.timestamp = ->
  Math.floor(new Date().getTime() / 1000)
###*
# Deletes `option_name` from `options` and return the value if present.
# If `options` doesn't contain `option_name` the default value is returned.
# @param {Object} options a collection
# @param {String} option_name the name (key) of the desired value
# @param [default_value] the value to return is option_name is missing
###
exports.option_consume = (options, option_name, default_value) ->
  result = options[option_name]
  delete options[option_name]

  if result? then result else default_value

exports.build_array = (arg) ->
  if !arg?
    []
  else if _.isArray(arg)
    arg
  else
    [arg]

exports.encode_double_array = (array) ->
  array = utils.build_array(array)
  if array.length > 0 and _.isArray(array[0])
    array.map((e) -> utils.build_array(e).join(",")).join("|")
  else
    array.join(",")

exports.encode_key_value = (arg) ->
  if _.isObject(arg)
    pairs = for k, v of arg
      "#{k}=#{v}"
    pairs.join("|")
  else
    arg

exports.build_eager = (transformations) ->
  (for transformation in utils.build_array(transformations)
    transformation = _.clone(transformation)
    _.filter([utils.generate_transformation_string(transformation), transformation.format], utils.present).join("/")
  ).join("|")

exports.build_custom_headers = (headers) ->
  switch
    when !headers?
      undefined
    when _.isArray headers
      headers.join "\n"
    when _.isObject headers
      [k + ": " + v for k, v of headers].join "\n"
    else
      headers

exports.present = (value) ->
  not _.isUndefined(value) and ("" + value).length > 0

exports.generate_transformation_string = (options) ->
  if _.isArray(options)
    result = for base_transformation in options
      utils.generate_transformation_string(_.clone(base_transformation))
    return result.join("/")

  responsive_width = utils.option_consume(options, "responsive_width", config().responsive_width)
  width = options["width"]
  height = options["height"]
  size = utils.option_consume(options, "size")
  [options["width"], options["height"]] = [width, height] = size.split("x") if size

  has_layer = options.overlay or options.underlay
  crop = utils.option_consume(options, "crop")
  angle = utils.build_array(utils.option_consume(options, "angle")).join(".")
  no_html_sizes = has_layer or utils.present(angle) or crop == "fit" or crop == "limit" or responsive_width

  delete options["width"] if width and (width == "auto" or no_html_sizes or parseFloat(width) < 1)
  delete options["height"] if height and (no_html_sizes or parseFloat(height) < 1)

  background = utils.option_consume(options, "background")
  background = background and background.replace(/^#/, "rgb:")
  color = utils.option_consume(options, "color")
  color = color and color.replace(/^#/, "rgb:")
  base_transformations = utils.build_array(utils.option_consume(options, "transformation", []))
  named_transformation = []
  if _.filter(base_transformations, _.isObject).length > 0
    base_transformations = _.map(base_transformations, (base_transformation) ->
      if _.isObject(base_transformation)
        utils.generate_transformation_string(_.clone(base_transformation))
      else
        utils.generate_transformation_string(transformation: base_transformation)
    )
  else
    named_transformation = base_transformations.join(".")
    base_transformations = []

  effect = utils.option_consume(options, "effect")

  if _.isArray(effect)
    effect = effect.join(":")
  else if _.isObject(effect)
    effect = "#{key}:#{value}" for key,value of effect

  border = utils.option_consume(options, "border")
  if _.isObject(border)
    border = "#{border.width ? 2}px_solid_#{(border.color ? "black").replace(/^#/, 'rgb:')}"
  else if /^\d+$/.exec(border) #fallback to html border attributes
    options.border = border
    border = undefined

  flags = utils.build_array(utils.option_consume(options, "flags")).join(".")
  dpr = utils.option_consume(options, "dpr", config().dpr)

  if options["offset"]?
    [options["start_offset"], options["end_offset"]] = split_range(utils.option_consume(options, "offset"))

  params =
    a: angle
    b: background
    bo: border
    c: crop
    co: color
    dpr: dpr
    e: effect
    fl: flags
    h: height
    t: named_transformation
    w: width

  simple_params =
    aspect_ratio: "ar"
    audio_codec: "ac"
    audio_frequency: "af"
    bit_rate: 'br'
    color_space: "cs"
    default_image: "d"
    delay: "dl"
    density: "dn"
    duration: "du"
    end_offset: "eo"
    fetch_format: "f"
    gravity: "g"
    opacity: "o"
    page: "pg"
    prefix: "p"
    quality: "q"
    radius: "r"
    start_offset: "so"
    video_codec: "vc"
    video_sampling: "vs"
    x: "x"
    y: "y"
    zoom: "z"

  for param, short of simple_params
    params[short] = utils.option_consume(options, param)
  
  # don't sort since we dont care
  params = _.reduce(params, (a, v, k) =>
    a.push([k, v])
    return a
  , [])

  # params = _.sortBy([key, value] for key, value of params, (key, value) -> key)
  params.push [utils.option_consume(options, "raw_transformation")]
  transformations = (param.join("_") for param in params when utils.present(_.last(param))).join(",")
  base_transformations.push transformations
  transformations = base_transformations
  if responsive_width
    responsive_width_transformation = config().responsive_width_transformation or DEFAULT_RESPONSIVE_WIDTH_TRANSFORMATION
    transformations.push utils.generate_transformation_string(_.clone(responsive_width_transformation))
  if width == "auto" or responsive_width
    options.responsive = true
  if dpr == "auto"
    options.hidpi = true
  _.filter(transformations, utils.present).join "/"

exports.url = (public_id, options = {}) ->
  type = utils.option_consume(options, "type", null)
  options.fetch_format ?= utils.option_consume(options, "format") if type is "fetch"
  transformation = utils.generate_transformation_string(options)
  resource_type = utils.option_consume(options, "resource_type", "image")
  version = utils.option_consume(options, "version")
  format = utils.option_consume(options, "format")
  cloud_name = utils.option_consume(options, "cloud_name", config().cloud_name)
  throw "Unknown cloud_name"  unless cloud_name
  private_cdn = utils.option_consume(options, "private_cdn", config().private_cdn)
  secure_distribution = utils.option_consume(options, "secure_distribution", config().secure_distribution)
  secure = utils.option_consume(options, "secure", null)
  ssl_detected = utils.option_consume(options, "ssl_detected", config().ssl_detected)
  secure = ssl_detected || config().secure if secure == null
  cdn_subdomain = utils.option_consume(options, "cdn_subdomain", config().cdn_subdomain)
  secure_cdn_subdomain = utils.option_consume(options, "secure_cdn_subdomain", config().secure_cdn_subdomain)
  cname = utils.option_consume(options, "cname", config().cname)
  shorten = utils.option_consume(options, "shorten", config().shorten)
  sign_url = utils.option_consume(options, "sign_url", config().sign_url)
  api_secret = utils.option_consume(options, "api_secret", config().api_secret)
  url_suffix = utils.option_consume(options, "url_suffix")
  use_root_path = utils.option_consume(options, "use_root_path", config().use_root_path)

  preloaded = /^(image|raw)\/([a-z0-9_]+)\/v(\d+)\/([^#]+)$/.exec(public_id)
  if preloaded
    resource_type = preloaded[1]
    type = preloaded[2]
    version = preloaded[3]
    public_id = preloaded[4]

  if url_suffix and not private_cdn
    throw 'URL Suffix only supported in private CDN'

  original_source = public_id
  return original_source unless public_id?
  public_id = public_id.toString()

  if type == null && public_id.match(/^https?:\//i)
    return original_source

  [ resource_type , type ] = finalize_resource_type(resource_type, type, url_suffix, use_root_path, shorten)
  [ public_id, source_to_sign ]= finalize_source(public_id, format, url_suffix)


  version ?= 1 if source_to_sign.indexOf("/") > 0 && !source_to_sign.match(/^v[0-9]+/) && !source_to_sign.match(/^https?:\//)
  version = "v#{version}" if version?

  transformation = transformation.replace(/([^:])\/\//, '\\1\/')


  prefix = unsigned_url_prefix(public_id, cloud_name, private_cdn, cdn_subdomain, secure_cdn_subdomain, cname, secure, secure_distribution)
  url = [prefix, resource_type, type, transformation, version,
    public_id].filter((part) -> part? && part != '').join('/')
  url

exports.video_url = (public_id, options) ->
  options = _.extend({resource_type: 'video'}, options)
  utils.url(public_id, options)

finalize_source = (source, format, url_suffix) ->
  source = source.replace(/([^:])\/\//, '\\1\/')
  if source.match(/^https?:\//i)
    source = smart_escape(source)
    source_to_sign = source
  else
    source = smart_escape(decodeURIComponent(source))
    source_to_sign = source
    if !!url_suffix
      throw new Error('url_suffix should not include . or /') if url_suffix.match(/[\.\/]/)
      source = source + '/' + url_suffix
    if format?
      source = source + '.' + format
      source_to_sign = source_to_sign + '.' + format
  [source, source_to_sign]

exports.video_thumbnail_url = (public_id, options) ->
  options = _.extend({}, exports.DEFAULT_POSTER_OPTIONS, options)
  utils.url(public_id, options)

finalize_resource_type = (resource_type, type, url_suffix, use_root_path, shorten) ->
  type?='upload'
  if url_suffix?
    if resource_type == 'image' && type == 'upload'
      resource_type = "images"
      type = null
    else if resource_type == 'raw' && type == 'upload'
      resource_type = 'files'
      type = null
    else
      throw new Error("URL Suffix only supported for image/upload and raw/upload")
  if use_root_path
    if (resource_type == 'image' && type == 'upload') || (resource_type == 'images' && !type?)
      resource_type = null
      type = null
    else
      throw new Error("Root path only supported for image/upload")
  if shorten && resource_type == 'image' && type == 'upload'
    resource_type = 'iu'
    type = null
  [resource_type, type]

# cdn_subdomain and secure_cdn_subdomain
# 1) Customers in shared distribution (e.g. res.cloudinary.com)
#   if cdn_domain is true uses res-[1-5].cloudinary.com for both http and https. Setting secure_cdn_subdomain to false disables this for https.
# 2) Customers with private cdn 
#   if cdn_domain is true uses cloudname-res-[1-5].cloudinary.com for http
#   if secure_cdn_domain is true uses cloudname-res-[1-5].cloudinary.com for https (please contact support if you require this)
# 3) Customers with cname
#   if cdn_domain is true uses a[1-5].cname for http. For https, uses the same naming scheme as 1 for shared distribution and as 2 for private distribution.
#
unsigned_url_prefix = (source, cloud_name, private_cdn, cdn_subdomain, secure_cdn_subdomain, cname, secure, secure_distribution) ->
  return '/res' + cloud_name if cloud_name.indexOf("/") == 0

  shared_domain = !private_cdn

  if secure
    if !secure_distribution? || secure_distribution == exports.OLD_AKAMAI_SHARED_CDN
      secure_distribution = if private_cdn then cloud_name + "-res.cloudinary.com" else exports.SHARED_CDN
    shared_domain ?= secure_distribution == exports.SHARED_CDN
    secure_cdn_subdomain = cdn_subdomain if !secure_cdn_subdomain? && shared_domain

    if secure_cdn_subdomain
      secure_distribution = secure_distribution.replace('res.cloudinary.com', 'res-' + ((crc32(source) % 5) + 1 + '.cloudinary.com'))

    prefix = 'https://' + secure_distribution
  else if cname
    subdomain = if cdn_subdomain then 'a' + ((crc32(source) % 5) + 1) + '.' else ''
    prefix = 'http://' + subdomain + cname
  else
    cdn_part = if private_cdn then cloud_name + '-' else ''
    subdomain_part = if cdn_subdomain then '-' + ((crc32(source) % 5) + 1) else ''
    host = [cdn_part, 'res', subdomain_part, '.cloudinary.com'].join('')
    prefix = 'http://' + host

  prefix += '/' + cloud_name if shared_domain
  prefix


# Based on CGI::unescape. In addition does not escape / :
smart_escape = (string)->
  encodeURIComponent(string).replace(/%3A/g, ":").replace(/%2F/g, "/")

exports.merge = (hash1, hash2) ->
  result = {}
  result[k] = hash1[k] for k, v of hash1
  result[k] = hash2[k] for k, v of hash2
  result

join_pair = (key, value) ->
  if !value
    undefined
  else if value is true
    return key
  else
    return key + "='" + value + "'";

exports.html_attrs = (attrs) ->
  pairs = _.filter(_.map(attrs, (value, key) -> return join_pair(key, value)))
  pairs.sort()
  return pairs.join(" ")

number_pattern = "([0-9]*)\\.([0-9]+)|([0-9]+)"

offset_any_pattern = "(#{number_pattern})([%pP])?"

# Replace with ///(#{offset_any_pattern()})\.\.(#{offset_any_pattern()})///
# After jetbrains fixes bug
offset_any_pattern_re = RegExp("(#{offset_any_pattern})\\.\\.(#{offset_any_pattern})")

# Split a range into the start and end values
split_range = (range) -> # :nodoc:
  switch range.constructor
    when String
      range.split ".." if offset_any_pattern_re = ~range
    when Array
      [_.first(range), _.last(range)]
    else
      [null, null]

###*
# Normalize an offset value
# @param {String} value a decimal value which may have a 'p' or '%' postfix. E.g. '35%', '0.4p'
# @return {Object|String} a normalized String of the input value if possible otherwise the value itself
###
norm_range_value = (value) -> # :nodoc:
  offset = String(value).match(RegExp("^#{offset_any_pattern}$"))
  if offset
    modifier = if offset[5] then 'p' else ''
    value = "#{offset[1] || offset[4]}#{modifier}"
  value

###*
# A video codec parameter can be either a String or a Hash.
# @param {Object} param <code>vc_<codec>[ : <profile> : [<level>]]</code>
#                       or <code>{ codec: 'h264', profile: 'basic', level: '3.1' }</code>
# @return {String} <code><codec> : <profile> : [<level>]]</code> if a Hash was provided
#                   or the param if a String was provided.
#                   Returns null if param is not a Hash or String
###
process_video_params = (param) ->
  switch param.constructor
    when Object
      video = ""
      if 'codec' of param
        video = param['codec']
        if 'profile' of param
          video += ":" + param['profile']
          if 'level' of param
            video += ":" + param['level']
      video
    when String
      param
    else
      null

build_custom_headers = (headers)->
  (for a in Array(headers) when a?.join?
    a.join(": ")
  ).join("\n")

###*
# @private
###
build_eager = (eager)->
  return undefined unless eager?
  ret = (for transformation in Array(eager)
    transformation = _.clone(transformation)
    format = transformation.format if transformation.format?
    delete transformation.format
    _.compact([utils.generate_transformation_string(transformation), format]).join("/")
  ).join("|")
  ret


hashToQuery = (hash)->
  _.compact(for key, value of hash
    if _.isArray(value)
      (for v in value
        key = "#{key}[]" unless key.match(/\w+\[\]/)
        "#{querystring.escape("#{key}")}=#{querystring.escape(v)}"
      ).join("&")
    else
      "#{querystring.escape(key)}=#{querystring.escape(value)}"
  ).sort().join('&')

