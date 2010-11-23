require 'spec_helper'

describe "A request for a protected resource" do
  controller(ActionController::Base) do
    authenticate_with_oauth

    def new
      render :text => "Current oauth scope: #{oauth_access_token.scope}"
    end
  end

  before :each do
    @token = create_access_token(:access_grant => build_access_grant(:scope => "read write"))
  end

  describe "with no token passed" do
    before :each do
      get :new
    end

    it "responds with status 401" do
      response.status.should == 401
    end

    it "includes an OAuth challenge in the response" do
      response.headers['WWW-Authenticate'].should == "OAuth realm='Application'"
    end
  end

  describe "with a token passed as an oauth_token parameter" do
    before :each do
      get :new, :oauth_token => @token.access_token
    end

    it "is successful" do
      response.should be_successful
    end

    it "makes the access token available to the requested action" do
      response.body.should == "Current oauth scope: read write"
    end
  end

  describe "with a token passed in an Authorization header" do
    before :each do
      request.env['HTTP_AUTHORIZATION'] = "OAuth #{@token.access_token}"
      get :new
    end

    it "is successful" do
      response.should be_successful
    end

    it "makes the access token available to the requested action" do
      response.body.should == "Current oauth scope: read write"
    end
  end

  describe "with tokens passed in both the Authorization header and oauth_token parameter" do
    before :each do
      request.env['HTTP_AUTHORIZATION'] = "OAuth #{@token.access_token}"
      get :new, :oauth_token => @token.access_token
    end

    it "responds with status 400" do
      response.status.should == 400
    end

    it "includes a 'bad_request' OAuth challenge in the response" do
      response.headers['WWW-Authenticate'].should == "OAuth realm='Application', error='invalid_request'"
    end
  end

  describe "any failing request" do
    it "neuters warden if warden is present" do
      request.env['warden'] = stub(:warden)
      request.env['warden'].should_receive(:custom_failure!)
      get :new
    end
  end

  describe "with an invalid token" do
    before :each do
      get :new, :oauth_token => 'invalid-token'
    end

    it "responds with status 401" do
      response.status.should == 401
    end

    it "includes an 'invalid_token' OAuth challenge in the response" do
      response.headers['WWW-Authenticate'].should == "OAuth realm='Application', error='invalid_token'"
    end
  end

  describe "with an expired token that can be refreshed" do
    before :each do
      @token.update_attributes(:expires_at => 1.day.ago)
      get :new, :oauth_token => @token.access_token
    end

    it "responds with status 401" do
      response.status.should == 401
    end

    it "includes an 'invalid_token' OAuth challenge in the response" do
      response.headers['WWW-Authenticate'].should == "OAuth realm='Application', error='expired_token'"
    end
  end

  describe "with an expired token that can't be refreshed" do
    before :each do
      @token.update_attributes(:expires_at => 1.day.ago, :refresh_token => nil)
      get :new, :oauth_token => @token.access_token
    end

    it "responds with status 401" do
      response.status.should == 401
    end

    it "includes an 'invalid_token' OAuth challenge in the response" do
      response.headers['WWW-Authenticate'].should == "OAuth realm='Application', error='invalid_token'"
    end
  end
end

describe "A request for a protected resource requiring a specific scope" do
  controller(ActionController::Base) do
    authenticate_with_oauth :scope => 'editor'

    def new
      render :text => "Current oauth scope: #{oauth_access_token.scope}"
    end
  end

  before :each do
    @token = create_access_token(:access_grant => build_access_grant(:scope => "reader editor admin"))
    @insufficient_token = create_access_token(:access_grant => build_access_grant(:scope => "reader admin"))
  end

  describe "made with a token with sufficient scope" do
    before :each do
      get :new, :oauth_token => @token.access_token
    end

    it "is successful" do
      response.should be_successful
    end
  end

  describe "made with a token with insufficient scope" do
    before :each do
      get :new, :oauth_token => @insufficient_token.access_token
    end

    it "responds with status 403" do
      response.status.should == 403
    end

    it "includes an 'invalid_token' OAuth challenge in the response" do
      response.headers['WWW-Authenticate'].should == "OAuth realm='Application', error='insufficient_scope'"
    end
  end
end