#
# Author:: John Keiser (<jkeiser@opscode.com>)
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/chef_fs/file_system/base_fs_dir'
require 'chef/chef_fs/file_system/rest_list_entry'
require 'chef/chef_fs/file_system/not_found_error'

class Chef
  module ChefFS
    module FileSystem
      class PolicyGroupsDir < RestListDir

        def our_api_path(object)
          require 'pry'; binding.pry
          "#{api_path}/#{object["name"]}/policies/#{object[]}"
        end

        # RestListDir does POST to the normal URL, but we do PUT to
        # /organizations/{organization}/policy_groups/{policy_group}/policies/{policy_name}
        def create_child(name, file_contents)
          # Parse the contents to ensure they are valid JSON
          begin
            object = Chef::JSONCompat.parse(file_contents)
          rescue Chef::Exceptions::JSON::ParseError => e
            raise Chef::ChefFS::FileSystem::OperationFailedError.new(:create_child, self, e), "Parse error reading JSON creating child '#{name}': #{e}"
          end

          # Create the child entry that will be returned
          result = make_child_entry(name, true)

          if data_handler
            object = data_handler.normalize_for_put(object, result)
            data_handler.verify_integrity(object, result) do |error|
              raise Chef::ChefFS::FileSystem::OperationFailedError.new(:create_child, self), "Error creating '#{name}': #{error}"
            end
          end

          begin
            path = our_api_path(object)
            rest.put(path, object)
          rescue Timeout::Error => e
            raise Chef::ChefFS::FileSystem::OperationFailedError.new(:create_child, self, e), "Timeout creating '#{name}': #{e}"
          rescue Net::HTTPServerException => e
            # 404 = NotFoundError
            if e.response.code == "404"
              raise Chef::ChefFS::FileSystem::NotFoundError.new(self, e)
            # 409 = AlreadyExistsError
            elsif $!.response.code == "409"
              raise Chef::ChefFS::FileSystem::AlreadyExistsError.new(:create_child, self, e), "Failure creating '#{name}': #{path}/#{name} already exists"
            # Anything else is unexpected (OperationFailedError)
            else
              raise Chef::ChefFS::FileSystem::OperationFailedError.new(:create_child, self, e), "Failure creating '#{name}': #{e.message}"
            end
          end

          # Clear the cache of children so that if someone asks for children
          # again, we will get it again
          @children = nil

          result
        end
      end
    end
  end
end
