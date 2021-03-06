require "http/server"
require "mime"
require "crypto/md5"

module Amatista
  # Helpers used by the methods in the controller class.
  module Helpers
    # Redirects to an url
    #
    # Example
    # ```crystal
    # redirect_to "/tasks"
    # ```
    def redirect_to(path)
      add_headers :location, path
      HTTP::Response.new 303, "redirection", set_headers
    end

    # Makes a respond based on context type
    # The body argument should be string if used html context type
    def respond_to(context, body)
      context = Mime.from_ext(context).to_s
      add_headers :context, context
      HTTP::Response.new 200, body, set_headers
    end

    # Send data as attachment
    def send_data(body, filename, disposition="attachment")
      add_headers :disposition, "attachment; filename='#{filename}'"
      HTTP::Response.new 200, body, set_headers
    end

    def add_cache_control(max_age = 31536000, public = true)
      state = public ? "public" : "private"
      add_headers :cache, "#{state}, max-age=#{max_age}"
    end

    def add_last_modified(resource)
      add_headers :last_modified, File.stat(resource).mtime.to_s
    end

    def add_etag(resource)
      stat = File.stat(resource)
      to_encrypt = stat.ino + stat.size + stat.mtime.ticks
      add_headers :etag, Crypto::MD5.hex_digest(to_encrypt.to_s)
    end

    def set_headers
      headers = @@header
      @@header = HTTP::Headers.new
      headers || HTTP::Headers.new
    end

    private def add_headers(type, value)
      @@header = HTTP::Headers.new unless @@header

      header_label = {context:       "Content-Type",
                      location:      "Location",
                      cache:         "Cache-Control",
                      last_modified: "Last-Modified",
                      disposition:   "Content-Disposition",
                      etag:          "ETag"}
    
      header = @@header
      if header
        header.add(header_label[type], value)
        header.add("Set-Cookie", send_sessions_to_cookie) unless has_session?
      end
      @@header = header
    end

    # Find out the IP address
    def remote_ip
      return unless request = $amatista.request

      headers = %w(X-Forwarded-For Proxy-Client-IP WL-Proxy-Client-IP HTTP_X_FORWARDED_FOR HTTP_X_FORWARDED
      HTTP_X_CLUSTER_CLIENT_IP HTTP_CLIENT_IP HTTP_FORWARDED_FOR HTTP_FORWARDED HTTP_VIA
      REMOTE_ADDR)

      headers.map{|header| request.headers[header]? as String | Nil}.compact.first
    end
  end
end
