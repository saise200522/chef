require 'chef/chef_fs/data_handler/data_handler_base'

class Chef
  module ChefFS
    module DataHandler
      class PolicyGroupDataHandler < DataHandlerBase

        def normalize(policy_group, entry)
          defaults = {
            "name" => remove_dot_json(entry.name),
            "policies" => {}
          }
          result = normalize_hash(policy_group, defaults)
          result.delete("uri") # not useful data
          result
        end
      end
    end
  end
end
