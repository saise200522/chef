require 'chef/chef_fs/file_system/rest_list_entry'
require 'chef/chef_fs/data_handler/policy_data_handler'

class Chef
  module ChefFS
    module FileSystem
      # /policies/NAME-REVISION.json
      # Represents the actual data at /organizations/ORG/policies/NAME/revisions/REVISION
      class PolicyRevisionEntry < RestListEntry

        # /policies/foo-1.0.0.json -> /policies/foo/revisions/1.0.0
        def api_path(options={})
          policy_name, revision_id = data_handler.name_and_revision(name)
          if options[:post_only]
            "#{parent.api_path}/#{policy_name}/revisions"
          else
            "#{parent.api_path}/#{policy_name}/revisions/#{revision_id}"
          end
        end

        # RestListEntry does PUT /organizations/ORG/policies/NAME/revisions/REVISION
        # but we need to do POST /organizations/ORG/policies/NAME/revisions
        def write(file_contents)
          begin
            object = Chef::JSONCompat.parse(file_contents)
          rescue Chef::Exceptions::JSON::ParseError => e
            raise Chef::ChefFS::FileSystem::OperationFailedError.new(:write, self, e), "Parse error reading JSON: #{e}"
          end

          if data_handler
            object = data_handler.normalize_for_post(object, self)
            data_handler.verify_integrity(object, self) do |error|
              raise Chef::ChefFS::FileSystem::OperationFailedError.new(:write, self), "#{error}"
            end
          end

          begin
            rest.post(api_path(post_only: true), object)
          rescue Timeout::Error => e
            raise Chef::ChefFS::FileSystem::OperationFailedError.new(:write, self, e), "Timeout writing: #{e}"
          rescue Net::HTTPServerException => e
            if e.response.code == "404"
              raise Chef::ChefFS::FileSystem::NotFoundError.new(self, e)
            else
              raise Chef::ChefFS::FileSystem::OperationFailedError.new(:write, self, e), "HTTP error writing: #{e}"
            end
          end
        end

      end
    end
  end
end
