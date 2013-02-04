require 'fog/octocloud'
require 'fog/compute'
require 'base64'
require 'json'

module Fog
  module Compute
    class Octocloud < Fog::Service
      VMRUN = "/Applications/VMware\\ Fusion.app/Contents/Library/vmrun"

      recognizes :loin_dir, :octocloud_api_key, :octocloud_url

      model_path 'fog/octocloud/models/compute'
      model       :server
      collection  :servers
      model       :cube
      collection  :cubes

      request_path 'fog/octocloud/requests/compute'

      ## local
      # fusion interaction
      request :vm_running
      request :start_vm
      request :stop_vm
      request :delete_fusion_vm
      request :vm_ip
      request :share_folder
      # filesystem interaction
      request :list_boxes
      request :list_defined_vms
      request :create_vm
      request :delete_vm_files
      request :delete_box
      request :import_box

      ## remote
      request :create_vm
      request :list_vms
      request :lookup_vm
      request :delete_vm
      request :create_cube
      request :list_cubes
      request :get_cube
      request :update_cube
      request :delete_cube


      class Mock

        def initialize(options)
        end

        def request(options)
          raise "Not implemented"
        end
      end

      class Real

        def initialize(options)
          # local
          @loin_dir     = options[:loin_dir] || "~/.tenderloin"
          @local_mode = true
          @box_dir = Pathname.new(File.join(@loin_dir, 'boxes')).expand_path
          @vm_dir = Pathname.new(File.join(@loin_dir, 'vms')).expand_path

          # remote
          @octocloud_url            = options[:octocloud_url] || Fog.credentials[:octocloud_url]
          @octocloud_api_key        = options[:octocloud_api_key] || Fog.credentials[:octocloud_api_key]
          @connection_options       = options[:connection_options] || {}
          @persistent               = options[:persistent] || false
          if @octocloud_url || @octocloud_api_key
            @connection = Fog::Connection.new(@octocloud_url, @persistent, @connection_options)
            @local_mode = false
          end
        end

        def vmx_for_vm(name)
          @vm_dir.join(name, name + ".vmx")
        end

        def vmrun(cmd, args={})
          args[:vmx] = args[:vmx].to_s if args[:vmx].kind_of? Pathname
          runcmd = "#{VMRUN} #{cmd} #{args[:vmx]} #{args[:opts]}"
          retrycount = 0
          while true
            res = `#{runcmd}`
            if $? == 0
              return res
            elsif res =~ /The virtual machine is not powered on/
              return
            else
              if res =~ /VMware Tools are not running/
                sleep 1; next unless retrycount > 10
              end
              raise "Error running vmrun command:\n#{runcmd}\nResponse: " + res
            end
          end
        end

        def remote_request(options)

          login = Base64.urlsafe_encode64(@octocloud_api_key + ":")

          headers = options[:headers] || {}
          headers = {'Authorization' => "Basic #{login}"}.merge(headers)

          if options[:body].kind_of? Hash
            options[:body] = options[:body].to_json
            headers = {'Content-Type' => 'application/json'}.merge(headers)
          end

          options = {
            :expects => 200,
            :query => "",
            :headers => headers,
          }.merge(options)

          response = @connection.request(options)

          if response.body.empty?
            true
          else
            Fog::JSON.decode(response.body)
          end
        end

        private

        # def to_dotted_hash(source, target = {}, namespace = nil)
        #   prefix = "#{namespace}." if namespace
        #   case source
        #   when Hash
        #     source.each do |key, value|
        #       to_dotted_hash(value, target, "#{prefix}#{key}")
        #     end
        #   when Array
        #     source.each_with_index do |value, index|
        #       to_dotted_hash(value, target, "#{prefix}#{index}")
        #     end
        #   else
        #     target[namespace] = source
        #   end
        #   target
        # end


      end
    end
  end
end