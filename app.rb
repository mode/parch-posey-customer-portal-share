require 'uri'
require 'sinatra'
require 'open-uri'
require 'net/http'
require 'json'

enable :sessions

HOST     = "https://modeanalytics.com"
OVERVIEW = "/demo/reports/9b259ce083b5/embed"
DETAILS  = "/demo/reports/e7aa896b87fa/embed"
ACCESS_KEY = 'insertaccesskeyhere'
ACCESS_SECRET = 'insertaccesssecrethere'

$userTable = {
  "utc"         => {"password" => "pw", "account_id" => 1441, "account_name" => "United Technologies"},
  "walmart"     => {"password" => "pw", "account_id" => 1001, "account_name" => "Walmart"},
  "tyson"       => {"password" => "pw", "account_id" => 1651, "account_name" => "Tyson Foods"},
  "merck"       => {"password" => "pw", "account_id" => 1711, "account_name" => "Merck"},
  "caterpillar" => {"password" => "pw", "account_id" => 1581, "account_name" => "Caterpillar"}
}

helpers do

  def logged_in?
    if session[:username].nil?
      false
    else
      true
    end
  end

end

get "/" do
  if logged_in?
    redirect "/overview"
  else
    redirect "/login"
  end
end

get "/login" do
  if logged_in?
    redirect "/overview"
  else
    erb :login
  end
end

post "/login" do
  if check_un_pw(params)
    user = $userTable[params[:username]]
    
    session[:username] = params[:username]
    session[:account_id] = user["account_id"]
    session[:account_name] = user["account_name"]
    
    redirect "/overview"
  else 
    redirect "/login"
  end
end

post "/logout" do
  session[:username] = nil
  session[:account_id] = nil
  session[:account_name] = nil
  
  redirect "/login"
end

get "/overview" do
  if logged_in?
    @host              = HOST
    @iframe_src        = create_embed_url(OVERVIEW, nil)
    @page              = "overview"
    @token             = "48fbb7578aa6"

    erb :index
  else
    redirect "/login"
  end
end

get "/details" do
  if logged_in?
    @host              = HOST
    @iframe_src        = create_embed_url(DETAILS, nil)
    @page              = "details"
    @token             = "86ed04e963bc"
    
    erb :index
  else
    redirect "/login"  
  end  
end

def check_un_pw(params)
  if $userTable.has_key?(params["username"])
    user = $userTable[params["username"]]    
    if params["password"] == user["password"]
      true
    end
  end
end

def create_embed_url(path, additional_params)
  timestamp = Time.now.to_i
  
  query_params = {
    timestamp: timestamp,
    max_age: 604800,
    param_account_id: session["account_id"],
    access_key: ACCESS_KEY
  }

  if additional_params
    query_params = query_params.merge(additional_params)
  end

  query_string = URI.encode_www_form(query_params)
  original_url = "#{HOST}#{path}?#{query_string}"
  sign_url(original_url, timestamp)
end

def sign_url(original, timestamp)
  raw_params    = URI.decode_www_form(URI.parse(original).query)
  sorted_params = raw_params.sort_by { |key, _value| key }
  query_string  = URI.encode_www_form(sorted_params)
  content_md5   = Digest::MD5.base64digest('')

  uri_to_sign       = URI.parse(original)
  uri_to_sign.query = query_string
  uri_to_sign       = uri_to_sign.to_s

  canonical = ['GET', nil, content_md5, uri_to_sign, timestamp].join(',')
  
  digest        = OpenSSL::Digest.new('sha256')
  signature     = OpenSSL::HMAC.hexdigest(digest, ACCESS_SECRET, canonical)
  
  final                    = URI.parse(original)
  final_params             = raw_params.to_h
  final_params[:signature] = signature
  final.query              = URI.encode_www_form(final_params)
  final.to_s
end
