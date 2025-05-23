#
# Copyright (c) 2006-2025 Wade Alcorn - wade@bindshell.net
# Browser Exploitation Framework (BeEF) - https://beefproject.com
# See the file 'doc/COPYING' for copying permission
#
module BeEF
  module Core
    module NetworkStack
      module Handlers
        # @note Redirector is used as a Rack app for mounting HTTP redirectors, instead of content
        # @todo Add new options to specify what kind of redirect you want to achieve
        class Redirector
          @target = ''

          def initialize(target)
            @target = target
          end

          def call(_env)
            @response = Rack::Response.new(
              body = ['302 found'],
              status = 302,
              header = {
                'Content-Type' => 'text',
                'Location' => @target
              }
            )
          end

          @request

          @response
        end
      end
    end
  end
end
