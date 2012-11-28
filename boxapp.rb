require 'rubygems' if RUBY_VERSION < '1.9'

#BoxApp using Sinatra , Box-API and Haml

require 'box-api'
require 'sinatra'
require 'rack-flash'
require 'haml'

# Sessions are used to keep track of user logins.
enable :sessions


# This is where we set the API key given by Box.
# Get a key here: https://www.box.net/developers/services
set :box_api_key, ENV['BOX_API_KEY']
Box_API = "z6uq0jbsoiz3qe3qhp4s5wrx08j05j7f"

helpers do
	
	# Requires the user to be logged into Box, or redirect them to the login page.
 	 def require_login
      #box_login(settings.box_api_key, session) do |auth_url|
      box_login(Box_API, session) do |auth_url|
      redirect auth_url
    end
  end
    def update_box_login
	    # update the variables if passed parameters (such as during a redirect)
	    session[:box_ticket] ||= params[:ticket]
	    session[:box_token] ||= params[:auth_token]
  	end



	# Authenticates the user using the given API key and session information.
    # The session information is used to keep the user logged in.
    def box_login(box_api_key, session)
      # make a new Account object using the API key
      account = Box::Account.new(box_api_key)

      # use a saved ticket or request a new one
      ticket = session[:box_ticket] || account.ticket
      token = session[:box_token]

      # try to authorize the account using the ticket and/or token
      authed = account.authorize(:ticket => ticket, :auth_token => token) do |auth_url|
        # this block is called if the authorization failed

        # save the ticket we used for later
        session[:box_ticket] = ticket

        # yield with the url the user must visit to authenticate
        yield auth_url if block_given?
      end

      if authed
        # authentication was successful, save the token for later
        session[:box_token] = account.auth_token

        # return the account
        return account
      end
    end

    # Removes session information so the account is forgotten.

    # Note: This doesn't actually log the user out, it just clears the session data.
    def box_logout(session)
      session.delete(:box_token)
      session.delete(:box_ticket)
    end

    def full(template, locals = {})
    haml(template, :locals => locals)
  end

  # Renders a template, but without the entire layout (good for AJAX calls).
  def partial(template, locals = {})
    haml(template, :layout => false, :locals => locals)
  end


end
#Root of BoxApp

get '/' do 
  update_box_login            # updates login information if given
  account = require_login     # make sure the user is authorized
  root = account.root         # get the root folder of the account 

  full :index, :account => account, :root => root
end  
# Gets a folder by id and returns its details.
get "/folder/:folder_id" do |folder_id|
  account = require_login        # make sure the user is authorized
  folder = account.folder(folder_id) # get the folder by id

  # Note: Getting a folder by ID is fastest, but it won't know about its parents.
  # If you need this information, use 'account.root.find(:id => folder_id)' instead.

  partial :folder, :folder => folder # render the information about this folder
end


# Displays the form for adding a new folder based on the parent_id.
get "/folder/add/:parent_id" do |parent_id|
  partial :add_folder, :parent_id => parent_id
end

# Creates a new folder with the given information.
post "/folder/add/:parent_id" do |parent_id|
  account = require_login        # make sure the user is authorized
  parent = account.folder(parent_id) # get the parent folder by id

  name = params[:name]         # get the desired folder name
  folder = parent.create(name) # create a new folder with this name

  partial :item, :item => folder # render the information about this folder
end

#Copy the pitch file and create a new folder
post "/folder/pitch/:file_id" do |file_id|
  account = require_login
  parent = account.root

  name = params[:name]         # get the desired folder name
  folder = parent.create(name) # create a new folder with this name

  file = account.file(file_id) # get the file by id

  file1 = file.copy(folder)

  
end

# Gets a file by id and returns its details.
get "/file/:file_id" do |file_id|
  account = require_login  # make sure the user is authorized
  file = account.file(file_id) # get the file by id

  # Note: Getting a file by ID is fastest, but it won't know about its parents.
  # If you need this information, use 'account.root.find(:id => file_id)' instead.

  partial :file, :file => file # render the information about this file
end

# Displays the form for adding a new file based on the parent_id.
get "/file/add/:parent_id" do |parent_id|
  partial :add_file, :parent_id => parent_id
end

# Creates a new file with the given information.
post "/file/add/:parent_id" do |parent_id|
  account = require_login        # make sure the user is authorized
  parent = account.folder(parent_id) # get the parent folder by id

  tmpfile = params[:file][:tempfile] # get the path of the file
  name = params[:file][:filename]    # get the name of the file

  file = parent.upload(tmpfile) # upload the file by its path
  file.rename(name)             # rename the file to match its desired name

  redirect "/" # redirect to the home page
end



# Handles logout requests.
get "/logout" do
  box_logout(session)

  redirect "/" # redirect to the home page
end
