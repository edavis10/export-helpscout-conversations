require 'rest-client'
require 'json'

class NilClass
  def blank?
    true
  end

  def present?
    !blank?
  end
end

class String
  def blank?
    self.strip.empty?
  end

  def present?
    !blank?
  end

  def self.to_bool(str)
    return true if str == true || str =~ (/^(true|t|yes|y|1)$/i)
    return false if str == false || str.blank? || str =~ (/^(false|f|no|n|0)$/i)
    raise ArgumentError.new("invalid value for Boolean: \"#{str}\"")
  end

  def to_bool
    String.to_bool(self)
  end
end

API_URL = 'https://api.helpscout.net/v2'
MAILBOXES_PATH = 'mailboxes'
CONVERSATIONS_PATH = 'conversations'
THREADS_PATH = 'threads'
RATE_LIMIT = (ENV['HELPSCOUT_API_RATE_LIMIT'] || 150).to_i
RATE_LIMIT_SECONDS = (ENV['HELPSCOUT_API_RATE_LIMIT_SECONDS'] || 60).to_i
THREADS = (ENV['HELPSCOUT_THREADS'] || "true").to_bool
MAILBOXES = (ENV['HELPSCOUT_MAILBOXES'] || '').split(/\s*,\s*/)
CONVERSATION_STATUS = (ENV['HELPSCOUT_STATUS'] || 'all')
CONVERSATION_START_PAGE = ENV['HELPSCOUT_CONVERSATION_PAGE']
CONVERSATION_MAX_PAGES = ENV['HELPSCOUT_CONVERSATION_PAGES'].to_i
TOK_ENV = 'HELPSCOUT_API_TOKEN'
API_TOKEN = ENV[TOK_ENV]

def header(hdrs={})
  auth_header
end

def auth_header(hdrs={})
  if (API_TOKEN).blank?
    raise "#{TOK_ENV} must be set to authorization token"
  end
  base_header(Authorization: "Bearer #{API_TOKEN}")
end

def base_header(hdrs={})
  {
    'content-type' => 'text/json; charset=UTF-8'
  }.merge(hdrs)
end

def helpscout_api_get(path, data={}, opts={})
  check_rate_limit
  url = path_to_url(path, opts)
  resp = RestClient.get(url, header)
  return resp
rescue RestClient::InternalServerError, RestClient::Exceptions::OpenTimeout
  retry
end

def check_rate_limit
  return if RATE_LIMIT.zero?
  now = Time.now
  @requests ||= []
  # ignore requests more than RATE_LIMIT_SECONDS ago
  since = now - RATE_LIMIT_SECONDS
  @requests.each_with_index do |t, i|
    if t > since
      if i > 0
        @requests = @requests[i..-1]
      end
      break
    end
  end
  if @requests.size >= RATE_LIMIT
    since_secs = (now - @requests[0]).to_i
    sleep (RATE_LIMIT_SECONDS-since_secs)+1
  end
  @requests ||= []
  @requests << now
end

def get_mailbox_ids
  ids = []
  jresp = helpscout_api_get(path_to_url(MAILBOXES_PATH))
  resp = JSON.parse(jresp)
  if (rh = resp["_embedded"]).is_a?(Hash)
    mailboxes = resp["_embedded"]["mailboxes"]
    ids = mailboxes.select {|mb| MAILBOXES.empty? || MAILBOXES.include?(mb["id"].to_s) || MAILBOXES.include?(mb["slug"].to_s)}.map {|mb| mb["id"]}
  end
  ids
end

def add_url_params(url, params={})
  return url if params.empty?
  urlpieces = url.split(/\?/)
  uparams = urlpieces.size > 1 ? urlpieces[1].split(/\&/) : []
  uhparams = {}
  uparams.each do |uparam|
    upieces = uparam.split(/=/)
    uhparams[upieces[0]] = upieces[1]
  end
  params.each do |key, value|
    uhparams[key.to_s] = value
  end
  uparams = uhparams.to_a.map {|e| e.join('=')}
  urlpieces[0]+'?'+uparams.join('&')
end

def path_to_url(path, opts={})
  url = path
  url = [API_URL, path].join('/') unless url.match(/:/)
  if (params = opts[:params]).is_a?(Hash) && !params.empty?
    add_url_params(url, params)
  else
    url
  end
end

mids = get_mailbox_ids
mids.each do |mid|
  all_pages = 0
  page = nil
  pages = 0
  while page.nil? || page <= all_pages
    pages += 1
    unless CONVERSATION_MAX_PAGES.zero?
      break if pages > CONVERSATION_MAX_PAGES
    end
    page = CONVERSATION_START_PAGE.to_i if page.nil? && CONVERSATION_START_PAGE.present?
    params = {
      mailbox: mid,
      status: CONVERSATION_STATUS
    }
    params[:page] = page unless page.nil?
    url = path_to_url(CONVERSATIONS_PATH, params: params)
    jcresp = helpscout_api_get(url)
    puts jcresp
    cresp = JSON.parse(jcresp)
    raise "invalid conversations response received from #{url}: #{jcresp}" unless cresp.is_a?(Hash)
    if THREADS
      if (rh = cresp["_embedded"]).is_a?(Hash)
        convs = rh["conversations"]
        if convs.respond_to?(:each)
          convs.each do |conv|
            cid = conv["id"]
            if (links = conv["_links"]).is_a?(Hash) && (threads = links["threads"]).is_a?(Hash) && (threads_url = threads["href"]).present?
              tpage = nil
              tall_pages = 0
              while tpage.nil? || tpage <= tall_pages
                tparams = {}
                tparams[:page] = tpage unless tpage.nil?
                turl = path_to_url(threads_url, params: params)
                jtresp = helpscout_api_get(turl)
                tresp = JSON.parse(jtresp)
                raise "invalid threads response received from #{turl}: #{tresp}" unless tresp.is_a?(Hash)
                if !cid.nil? && (th = tresp["_embedded"]).is_a?(Hash) && th["conversation"].to_s.blank?
                  # add conversation these threads came from to threads response
                  th["conversation"] = cid
                  puts tresp.to_json
                else
                  puts jtresp
                end
                if (tpginfo = tresp["page"]).is_a?(Hash)
                  tall_pages = tpginfo["totalPages"]
                end
                tpage ||= 1
                tpage += 1
              end
            end
          end
        end
      end
    end
    if (pginfo = cresp["page"]).is_a?(Hash)
      all_pages = pginfo["totalPages"]
    end
    page ||= 1
    page += 1
  end
end
