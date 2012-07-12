require "rest-client"
require "sinatra"
require "uri"

# proxy network traffic through a socks5 server
require "socksify"
socks = URI.parse(ENV["PROXIMO_URL"].to_s)
TCPSocket::socks_server = socks.host
TCPSocket::socks_port = 1080
TCPSocket::socks_username = socks.user
TCPSocket::socks_password = socks.password

helpers do
  def proxy
    RestClient::Resource.new(ENV["PROXY_URL"] || "https://httpbin.org")
  end
end

get "/*" do

  # rebuild the full path and querystring
  path = request.env["REQUEST_PATH"] + "?" + request.env["QUERY_STRING"]

  # rack munges client headers, let's un-munge
  headers = request.env.select { |k,v| k =~ /^HTTP_/ }.inject({}) do |ax, (key, val)|
    ax.update(key.sub(/^HTTP_/, "").gsub("_", "-").split(/(\W)/).map(&:capitalize).join => val)
  end

  # delete host so RestClient can replace it
  headers.delete "Host"

  # proxy the request
  proxy[path].get(headers) do |res|

    # RestClient munges response headers, let's un-munge
    fixed_headers = res.raw_headers.inject({}) do |ax, (key, val)|
      ax.update(key => val.first)
    end

    # relay back to the user
    status res.code
    headers fixed_headers
    body res.to_s
  end

end

run Sinatra::Application
