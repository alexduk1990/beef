#
# Copyright (c) 2006-2025 Wade Alcorn - wade@bindshell.net
# Browser Exploitation Framework (BeEF) - https://beefproject.com
# See the file 'doc/COPYING' for copying permission
#

module BeEF
  module Core
    module Rest
      class Server < BeEF::Core::Router::Router
        config = BeEF::Core::Configuration.instance
        http_server = BeEF::Core::Server.instance

        before do
          error 401 unless params[:token] == config.get('beef.api_token')
          halt 401 unless BeEF::Core::Rest.permitted_source?(request.ip)
          headers 'Content-Type' => 'application/json; charset=UTF-8',
                  'Pragma' => 'no-cache',
                  'Cache-Control' => 'no-cache',
                  'Expires' => '0'
        end

        # @note Binds a local file to a specified path in BeEF's web server
        # Note: 'local_file' expects a file from the /extensions/social_engineering/droppers directory.
        # Example usage:
        # curl -H "Content-Type: application/json; charset=UTF-8" -d '{"mount":"/dropper","local_file":"dropper.exe"}'
        # -X POST -v http://10.0.60.10/api/server/bind?token=xyz

        post '/bind' do
          request.body.rewind
          begin
            data = JSON.parse request.body.read
            mount = data['mount']
            local_file = data['local_file']

            droppers_dir = "#{File.expand_path(__dir__)}/../../../../extensions/social_engineering/droppers/"

            if File.exist?(droppers_dir + local_file) && Dir.entries(droppers_dir).include?(local_file)
              f_ext = File.extname(local_file).gsub('.', '')
              f_ext = nil if f_ext.empty?
              BeEF::Core::NetworkStack::Handlers::AssetHandler.instance.bind("/extensions/social_engineering/droppers/#{local_file}", mount, f_ext)
              status 200
            else
              halt 400
            end
          rescue StandardError
            error 400
          end
        end

        get '/mounts' do
          { 'mounts' => http_server.mounts }.to_json
        end

        get '/version' do
          { 'version' => config.get('beef.version') }.to_json
        end
      end
    end
  end
end
