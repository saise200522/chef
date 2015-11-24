#
# Author:: Seth Chisamore (<schisamo@chef.io>)
# Author:: Matt Wrock <matt@mattwrock.com>
# Copyright:: Copyright (c) 2011, 2015 Chef Software, Inc.
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

# TODO: Allow @new_resource.source to be a Product Code as a GUID for uninstall / network install

require 'chef/mixin/shell_out'

class Chef
  class Provider
    class Package
      class Windows
        class Exe
          include Chef::Mixin::ShellOut

          def initialize(resource, installer_type)
            @new_resource = resource
            @installer_type = installer_type
          end

          # From Chef::Provider::Package
          def expand_options(options)
            options ? " #{options}" : ""
          end

          # Returns a version if the package is installed or nil if it is not.
          def installed_version
            Chef::Log.debug("#{@new_resource} checking package version")
            current_installed_version
          end

          def package_version
            @new_resource.version
          end

          def install_package
            Chef::Log.debug("#{@new_resource} installing #{@new_resource.installer_type} package '#{@new_resource.source}'")
            shell_out!(
              [
                "start",
                "\"\"",
                "/wait",
                "\"#{@new_resource.source}\"",
                unattended_installation_flags,
                expand_options(@new_resource.options),
                "& exit %%%%ERRORLEVEL%%%%"
              ].join(" "), timeout: @new_resource.timeout, returns: @new_resource.returns
            )
          end

          def remove_package
            uninstall_string = nil
            if @new_resource.version
              if installed_packages[@new_resource.version]
                uninstall_string = installed_packages[@new_resource.version][:uninstall_string]
              end
            else
              if installed_packages.keys.count == 1
                uninstall_string = installed_packages[installed_packages.keys[0]][:uninstall_string]
              else
                raise Chef::Exceptions::MultiplePackagesFound, "Removing Windows Package '#{@new_resource.name}' found versions '#{@new_resource.version}' and no version given"
              end
            end

            if uninstall_string.nil?
              raise Chef::Exceptions::PackageVersionNotFound, "Removing Windows Package '#{@new_resource.name}' no version '#{@new_resource.version}' found"
            end

            Chef::Log.info("Registry provided uninstall string for #{@new_resource} is '#{uninstall_string}'")
            uninstall_command = begin
              uninstall_string.delete!('"')
              "start \"\" /wait /d\"#{::File.dirname(uninstall_string)}\" #{::File.basename(uninstall_string)}#{expand_options(@new_resource.options)} /S & exit %%%%ERRORLEVEL%%%%"
            end
            Chef::Log.info("Removing #{@new_resource} with uninstall command '#{uninstall_command}'")
            shell_out!(uninstall_command, { returns: @new_resource.returns })
          end

          private

          def current_installed_version
            @current_installed_version ||= installed_packages.keys
          end

          def installed_packages
            @installed_packages || begin
              installed_packages = {}
              # Computer\HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall
              installed_packages.merge!(extract_installed_packages_from_key(::Win32::Registry::HKEY_LOCAL_MACHINE)) # rescue nil
              # 64-bit registry view
              # Computer\HKEY_LOCAL_MACHINE\Software\Wow6464Node\Microsoft\Windows\CurrentVersion\Uninstall
              installed_packages.merge!(extract_installed_packages_from_key(::Win32::Registry::HKEY_LOCAL_MACHINE, (::Win32::Registry::Constants::KEY_READ | 0x0100))) # rescue nil
              # 32-bit registry view
              # Computer\HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall
              installed_packages.merge!(extract_installed_packages_from_key(::Win32::Registry::HKEY_LOCAL_MACHINE, (::Win32::Registry::Constants::KEY_READ | 0x0200))) # rescue nil
              # Computer\HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall
              installed_packages.merge!(extract_installed_packages_from_key(::Win32::Registry::HKEY_CURRENT_USER)) # rescue nil
              installed_packages
            end
          end

          # http://unattended.sourceforge.net/installers.php
          def unattended_installation_flags
            case @installer_type
            when :installshield
              '/s /sms'
            when :nsis
              '/S /NCRC'
            when :inno
              # "/sp- /silent /norestart"
              '/verysilent /norestart'
            when :wise
              '/s'
            end
          end

          def extract_installed_packages_from_key(hkey = ::Win32::Registry::HKEY_LOCAL_MACHINE, desired = ::Win32::Registry::Constants::KEY_READ)
            uninstall_subkey = 'Software\Microsoft\Windows\CurrentVersion\Uninstall'
            packages = {}
            begin
              ::Win32::Registry.open(hkey, uninstall_subkey, desired) do |reg|
                reg.each_key do |key, _wtime|
                  begin
                    k = reg.open(key, desired)
                    display_name = k['DisplayName'] rescue nil
                    version = k['DisplayVersion'] rescue 'NO VERSION'
                    uninstall_string = k['UninstallString'] rescue nil

                    if display_name == @new_resource.package_name
                      packages[version] = {
                        name: display_name,
                        version: version,
                        uninstall_string: uninstall_string
                      }
                    end
                  rescue ::Win32::Registry::Error
                  end
                end
              end
            rescue ::Win32::Registry::Error
            end
            packages
          end
        end
      end
    end
  end
end
