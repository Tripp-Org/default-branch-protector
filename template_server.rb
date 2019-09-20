require 'sinatra'
require 'octokit'
require 'dotenv/load' # Manages environment variables
require 'json'
require 'openssl'     # Verifies the webhook signature
require 'jwt'         # Authenticates a GitHub App
require 'time'        # Gets ISO 8601 representation of a Time object
require 'logger'      # Logs debug statements

set :port, 3000
set :bind, '0.0.0.0'


# This is template code to create a GitHub App server.
# You can read more about GitHub Apps here: # https://developer.github.com/apps/
#
# On its own, this app does absolutely nothing, except that it can be installed.
# It's up to you to add functionality!
# You can check out one example in advanced_server.rb.
#
# This code is a Sinatra app, for two reasons:
#   1. Because the app will require a landing page for installation.
#   2. To easily handle webhook events.
#
# Of course, not all apps need to receive and process events!
# Feel free to rip out the event handling code if you don't need it.
#
# Have fun!
#

class GHAapp < Sinatra::Application

  PRIVATE_KEY = OpenSSL::PKey::RSA.new(ENV['GITHUB_PRIVATE_KEY'].gsub('\n', "\n"))
  WEBHOOK_SECRET = ENV['GITHUB_WEBHOOK_SECRET']
  APP_IDENTIFIER = ENV['GITHUB_APP_IDENTIFIER']
  GIT_HUB_COMMITTER = {"name"=>"GitHub", "email"=>"noreply@github.com", "username"=>"web-flow"}
  

  # Turn on Sinatra's verbose logging during development
  configure :development do
    set :logging, Logger::DEBUG
  end


  # Before each request to the `/event_handler` route
  before '/event_handler' do
    get_payload_request(request)
    verify_webhook_signature
    authenticate_app
    # Authenticate the app installation in order to run API operations
    authenticate_installation(@payload)
  end


  post '/event_handler' do

    if repo_created_event?
      @@recently_created_repo_name = @payload['repository']['full_name'] 
      #this is not the best idea, thread safety and timing issues could occur, should really be in DB
    end
    
    if push_event?( request ) && initial_push?  
      protect_branch_and_notify
    end
      
    200 # success status
  end


  helpers do
    
    def protect_branch_and_notify()
      
      repo_name = @payload['repository']['full_name']
      default_branch = @payload['repository']['default_branch']
      
      @installation_client.protect_branch( repo_name, default_branch,
        enforce_admins: nil, required_pull_request_reviews: nil, restrictions: nil, 
        accept: 'application/vnd.github.luke-cage-preview+json'.freeze )
         #enhancement to add these as options for branch protection to be set in the env file
         
      @installation_client.create_issue( repo_name, "Protect #{default_branch}", 
        "Branch #{default_branch} protected. @lydiatripp" )
        #enhancement to get user name to be notified from environment vars
    end
    
    def initial_push?()
      
      GIT_HUB_COMMITTER == @payload['head_commit']['committer'] && 
        "Initial commit" == @payload['head_commit']['message'] &&
         @@recently_created_repo_name && @payload['repository']['full_name']
    end
    
    def push_event?( request )
      request.env['HTTP_X_GITHUB_EVENT'] == "push"
    end

    def repo_created_event?()
      @payload['action'] == "created"
    end

    # Saves the raw payload and converts the payload to JSON format
    def get_payload_request( request )
      # request.body is an IO or StringIO object
      # Rewind in case someone already read it
      request.body.rewind
      # The raw text of the body is required for webhook signature verification
      @payload_raw = request.body.read
      begin
        @payload = JSON.parse @payload_raw
      rescue => e
        fail  "Invalid JSON (#{e}): #{@payload_raw}"
      end
    end

    # Instantiate an Octokit client authenticated as a GitHub App.
    # GitHub App authentication requires that you construct a
    # JWT (https://jwt.io/introduction/) signed with the app's private key,
    # so GitHub can be sure that it came from the app an not altererd by
    # a malicious third party.
    def authenticate_app
      payload = {
          # The time that this JWT was issued, _i.e._ now.
          iat: Time.now.to_i,

          # JWT expiration time (10 minute maximum)
          exp: Time.now.to_i + (10 * 60),

          # Your GitHub App's identifier number
          iss: APP_IDENTIFIER
      }

      # Cryptographically sign the JWT.
      jwt = JWT.encode(payload, PRIVATE_KEY, 'RS256')

      # Create the Octokit client, using the JWT as the auth token.
      @app_client ||= Octokit::Client.new(bearer_token: jwt)
    end

    # Instantiate an Octokit client, authenticated as an installation of a
    # GitHub App, to run API operations.
    def authenticate_installation(payload)
      @installation_id = payload['installation']['id']
      @installation_token = @app_client.create_app_installation_access_token(@installation_id, 
        accept: 'application/vnd.github.machine-man-preview+json'.freeze)[:token]
      @installation_client = Octokit::Client.new(bearer_token: @installation_token)
    end

    # Check X-Hub-Signature to confirm that this webhook was generated by
    # GitHub, and not a malicious third party.
    #
    # GitHub uses the WEBHOOK_SECRET, registered to the GitHub App, to
    # create the hash signature sent in the `X-HUB-Signature` header of each
    # webhook. This code computes the expected hash signature and compares it to
    # the signature sent in the `X-HUB-Signature` header. If they don't match,
    # this request is an attack, and you should reject it. GitHub uses the HMAC
    # hexdigest to compute the signature. The `X-HUB-Signature` looks something
    # like this: "sha1=123456".
    # See https://developer.github.com/webhooks/securing/ for details.
    def verify_webhook_signature
      their_signature_header = request.env['HTTP_X_HUB_SIGNATURE'] || 'sha1='
      method, their_digest = their_signature_header.split('=')
      our_digest = OpenSSL::HMAC.hexdigest(method, WEBHOOK_SECRET, @payload_raw)
      halt 401 unless their_digest == our_digest

      # The X-GITHUB-EVENT header provides the name of the event.
      # The action value indicates the which action triggered the event.
      logger.debug "---- received event #{request.env['HTTP_X_GITHUB_EVENT']}"
      logger.debug "----    action #{@payload['action']}" unless @payload['action'].nil?
    end

  end

  # Finally some logic to let us run this server directly from the command line,
  # or with Rack. Don't worry too much about this code. But, for the curious:
  # $0 is the executed file
  # __FILE__ is the current file
  # If they are the same—that is, we are running this file directly, call the
  # Sinatra run method
  run! if __FILE__ == $0
end
