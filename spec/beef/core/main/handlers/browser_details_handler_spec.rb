#
# Copyright (c) 2006-2025 Wade Alcorn - wade@bindshell.net
# Browser Exploitation Framework (BeEF) - https://beefproject.com
# See the file 'doc/COPYING' for copying permission
#

require 'rest-client'
require 'json'
require_relative '../../../../spec_helper'
require_relative '../../../../support/constants'
require_relative '../../../../support/beef_test'

RSpec.describe 'Browser Details Handler', run_on_browserstack: true do
  before(:all) do

    @config = BeEF::Core::Configuration.instance
    db_file = @config.get('beef.database.file')
    print_info 'Resetting the database for BeEF.'
    File.delete(db_file) if File.exist?(db_file)
    @config.set('beef.credentials.user', 'beef')
    @config.set('beef.credentials.passwd', 'beef')
    @username = @config.get('beef.credentials.user')
    @password = @config.get('beef.credentials.passwd')

    # Load BeEF extensions and modules
    # Always load Extensions, as previous changes to the config from other tests may affect
    # whether or not this test passes.
    print_info 'Loading in BeEF::Extensions'
    BeEF::Extensions.load

    # Check if modules already loaded. No need to reload.
    if @config.get('beef.module').nil?
      print_info 'Loading in BeEF::Modules'
      BeEF::Modules.load
    else
      print_info 'Modules already loaded'
    end

    # Grab DB file and regenerate if requested
    print_info 'Loading database'

    # Load up DB and migrate if necessary
    ActiveRecord::Base.logger = nil
    OTR::ActiveRecord.configure_from_hash!(adapter: 'sqlite3', database: db_file)
    # otr-activerecord require you to manually establish the connection with the following line
    #Also a check to confirm that the correct Gem version is installed to require it, likely easier for old systems.
    if Gem.loaded_specs['otr-activerecord'].version > Gem::Version.create('1.4.2')
      OTR::ActiveRecord.establish_connection!
    end

    # Migrate (if required)
    ActiveRecord::Migrator.migrations_paths = [File.join('core', 'main', 'ar-migrations')]
    context = ActiveRecord::MigrationContext.new(ActiveRecord::Migrator.migrations_paths)
    ActiveRecord::Migrator.new(:up, context.migrations, context.schema_migration, context.internal_metadata).migrate if context.needs_migration?

    BeEF::Core::Migration.instance.update_db!

    # Spawn HTTP Server
    print_info 'Starting HTTP Hook Server'
    http_hook_server = BeEF::Core::Server.instance
    http_hook_server.prepare

    # Generate a token for the server to respond with
    @token = BeEF::Core::Crypto.api_token

    # Initiate server start-up
    @pids = fork do
      BeEF::API::Registrar.instance.fire(BeEF::API::Server, 'pre_http_start', http_hook_server)
    end
    @pid = fork do
      http_hook_server.start
    end

    begin
      @caps = CONFIG['common_caps'].merge(CONFIG['browser_caps'][TASK_ID])
      @caps['name'] = self.class.description || ENV['name'] || 'no-name'
      @caps['browserstack.local'] = true
      @caps['browserstack.video'] = true
      @caps['browserstack.localIdentifier'] = ENV['BROWSERSTACK_LOCAL_IDENTIFIER']

      @driver = Selenium::WebDriver.for(:remote,
                                        url: "http://#{CONFIG['user']}:#{CONFIG['key']}@#{CONFIG['server']}/wd/hub",
                                        options: @caps)
      # Hook new victim
      print_info 'Hooking a new victim, waiting a few seconds...'
      wait = Selenium::WebDriver::Wait.new(timeout: 30) # seconds

      @driver.navigate.to VICTIM_URL.to_s

      sleep 3

      sleep 1 until wait.until { @driver.execute_script('return window.beef.session.get_hook_session_id().length') > 0 }

      @session = @driver.execute_script('return window.beef.session.get_hook_session_id()')
    end
  end

  after(:all) do
    server_teardown(@driver, @pid, @pids)
  end

  it 'can successfully hook a browser' do
    expect(@session).not_to be_nil
  end

  it 'browser details handler working' do
    print_info 'Getting browser details'
    hooked_browser = BeEF::Core::Models::HookedBrowser.all.first
    details = JSON.parse(RestClient.get("#{RESTAPI_HOOKS}/#{hooked_browser.session}?token=#{@token}"))

    browser_name = if details['browser.name.friendly'].downcase == 'internet explorer'
                     'internet_explorer'
                   else
                     details['browser.name.friendly'].downcase
                   end

    expect(@driver.browser.to_s.downcase).to eq(browser_name)
  end
end
