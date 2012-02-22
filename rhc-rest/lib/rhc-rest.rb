# Copyright 2011 Red Hat, Inc.
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'rubygems'
require 'rest-client'
require 'logger'
require 'json'
require File.dirname(__FILE__) + '/rhc-rest/exceptions/exceptions.rb'
require File.dirname(__FILE__) + '/rhc-rest/application'
require File.dirname(__FILE__) + '/rhc-rest/cartridge'
require File.dirname(__FILE__) + '/rhc-rest/client'
require File.dirname(__FILE__) + '/rhc-rest/domain'
require File.dirname(__FILE__) + '/rhc-rest/key'
require File.dirname(__FILE__) + '/rhc-rest/user'

@@end_point = ""
@@headers = {:accept => :json}

module Rhc
  module Rest
    def logger
      if defined?Rails.logger
        Rails.logger
      else
        Logger.new(STDOUT)
      end
    end

    def parse_response(response)
      result = JSON.parse(response)
      type = result['type']
      data = result['data']
      case type
      when 'domains'
        domains = Array.new
        data.each do |domain_json|
          domains.push(Domain.new(domain_json))
        end
        return domains
      when 'domain'
        return Domain.new(data)
      when 'applications'
        apps = Array.new
        data.each do |app_json|
          apps.push(Application.new(app_json))
        end
        return apps
      when 'application'
        return Application.new(data)
      when 'cartridges'
        carts = Array.new
        data.each do |cart_json|
          carts.push(Cartridge.new(cart_json))
        end
        return carts
      when 'cartridge'
        return Cartridge.new(data)
      when 'user'
        return User.new(data)
      when 'keys'
        keys = Array.new
        data.each do |key_json|
          keys.push(Key.new(key_json))
        end
        return keys
      when 'key'
        return Key.new(data)
      else
      data
      end
    end

    def send(request)
      begin
        #puts request.headers
        response = request.execute
        #set cookie
        rh_sso = response.cookies['rh_sso']
        #puts response.cookies
        if not rh_sso.nil?
          @@headers["cookie"] = "rh_sso=#{rh_sso}"
        end
        #puts "#{response}"
        return parse_response(response) unless response.nil? or response.code == 204
      rescue RestClient::ExceptionWithResponse => e
      #puts "#{e.response}"
        process_error_response(e.response)
      rescue Exception => e
        raise ResourceAccessException.new("Failed to access resource: #{e.message}")
      end
    end

    def process_error_response(response)
      messages = Array.new
      begin
        result = JSON.parse(response)
        messages = result['messages']
      rescue Exception => e
        logger.debug "Response did not include a message from server"
      end
      case response.code
      when 401
        raise UnAuthorizedException.new("Not authenticated")
      when 403
        messages.each do |message|
          if message['severity'].upcase == "ERROR"
            raise RequestDeniedException.new(message['text'])
          end
        end
      when 404
        messages.each do |message|
          if message['severity'].upcase == "ERROR"
            raise ResourceNotFoundException.new(message['text'])
          end
        end
      when 409
        messages.each do |message|
          if message['severity'].upcase == "ERROR"
            raise ValidationException.new(message['text'])
          end
        end
      when 422
        puts "422"
        messages.each do |message|
          if message['severity'].upcase == "ERROR"
            raise ValidationException.new(message['text'], message['attribute'])
          end
        end
      when 400
        messages.each do |message|
          if message['severity'].upcase == "ERROR"
            raise ClientErrorException.new(message['text'])
          end
        end
      when 500
        messages.each do |message|
          if message['severity'].upcase == "ERROR"
            raise ServerErrorException.new(message['text'])
          end
        end
      when 503
        messages.each do |message|
          if message['severity'].upcase == "ERROR"
            raise ServiceUnavailableException.new(message['text'])
          end
        end
      end

    end
  end
end