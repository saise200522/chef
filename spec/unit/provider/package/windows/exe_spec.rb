#
# Author:: Matt Wrock <matt@mattwrock.com>
# Copyright:: Copyright (c) 2015 Chef Software, Inc.
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

require 'spec_helper'
require 'chef/provider/package/windows/exe'

describe Chef::Provider::Package::Windows::Exe do
  let(:package_name) { "calculator.exe" }
  let(:new_resource) { Chef::Resource::WindowsPackage.new(package_name) }
  let(:provider) { Chef::Provider::Package::Windows::Exe.new(new_resource, :nsis) }
  let(:file_version) { nil }
  let(:product_version) { nil }
  let(:version_info) { instance_double("Chef::ReservedNames::Win32::File::Version_info", FileVersion: file_version, ProductVersion: product_version) }

  before(:each) do
    allow(::File).to receive(:absolute_path).with(package_name).and_return(package_name)
    allow(Chef::ReservedNames::Win32::File).to receive(:version_info).and_return(version_info)
    allow(provider).to receive(:installed_packages).and_return(
      { 
        'outdated' => { 
          uninstall_string: File.join("uninst_dir", "uninst_file")
        }
      }
    )
  end

  it "responds to shell_out!" do
    expect(provider).to respond_to(:shell_out!)
  end

  describe "expand_options" do
    it "returns an empty string if passed no options" do
      expect(provider.expand_options(nil)).to eql ""
    end

    it "returns a string with a leading space if passed options" do
      expect(provider.expand_options("--train nope --town no_way")).to eql(" --train nope --town no_way")
    end
  end

  describe "installed_version" do
    it "returns the installed version" do
      expect(provider.installed_version).to eql(["outdated"])
    end
  end

  describe "package_version" do
    before do
       new_resource.version(nil)
    end

    context "both file and product version are in installer" do
      let(:file_version) { '1.1.1' }
      let(:product_version) { '1.1' }

      it "returns the file version" do
        expect(provider.package_version).to eql('1.1.1')
      end

      it "returns the version of a package if given" do
        new_resource.version('v55555')
        expect(provider.package_version).to eql('v55555')
      end
    end

    context "only file version is in installer" do
      let(:file_version) { '1.1.1' }

      it "returns the file version" do
        expect(provider.package_version).to eql('1.1.1')
      end

      it "returns the version of a package if given" do
        new_resource.version('v55555')
        expect(provider.package_version).to eql('v55555')
      end
    end

    context "only product version is in installer" do
      let(:product_version) { '1.1' }

      it "returns the product version" do
        expect(provider.package_version).to eql('1.1')
      end

      it "returns the version of a package if given" do
        new_resource.version('v55555')
        expect(provider.package_version).to eql('v55555')
      end
    end

    context "no version info is in installer" do
      let(:file_version) { nil }
      let(:product_version) { nil }

      it "returns the version of a package" do
        new_resource.version('v55555')
        expect(provider.package_version).to eql('v55555')
      end
    end

    context "no version info is in installer and none in attribute" do
      it "returns the version of a package" do
        expect(provider.package_version).to eql(nil)
      end
    end
  end

  describe "remove_package" do
    context "no version given and one package installed" do
      it "removes installed package" do
        expect(provider).to receive(:shell_out!).with(/start \"\" \/wait \/d\"uninst_dir\" uninst_file \/S & exit %%%%ERRORLEVEL%%%%/, kind_of(Hash))
        provider.remove_package
      end
    end

    context "several packages installed" do
      before do
        allow(provider).to receive(:installed_packages).and_return(
          { 
            'v1' => { 
              uninstall_string: File.join("uninst_dir1", "uninst_file1")
            },
            'v2' => { 
              uninstall_string: File.join("uninst_dir2", "uninst_file2")
            }
          }
        )
      end

      context "version given and installed" do
        it "removes given version" do
          new_resource.version('v2')
          expect(provider).to receive(:shell_out!).with(/start \"\" \/wait \/d\"uninst_dir2\" uninst_file2 \/S & exit %%%%ERRORLEVEL%%%%/, kind_of(Hash))
          provider.remove_package
        end
      end

      context "no version given" do
        it "raises MultiplePackagesFound" do
          expect{ provider.remove_package }.to raise_error(Chef::Exceptions::MultiplePackagesFound)
        end
      end

      context "version given but not installed" do
        it "raises PackageVersionNotFound" do
          new_resource.version('v3')
          expect{ provider.remove_package }.to raise_error(Chef::Exceptions::PackageVersionNotFound)
        end
      end
    end
  end

  context "installs nsis installer" do
    let(:provider) { Chef::Provider::Package::Windows::Exe.new(new_resource, :nsis) }

    it "calls installer with the correct flags" do
      expect(provider).to receive(:shell_out!).with(/start \"\" \/wait \"#{package_name}\" \/S \/NCRC  & exit %%%%ERRORLEVEL%%%%/, kind_of(Hash))
      provider.install_package
    end
  end

  context "installs installshield installer" do
    let(:provider) { Chef::Provider::Package::Windows::Exe.new(new_resource, :installshield) }

    it "calls installer with the correct flags" do
      expect(provider).to receive(:shell_out!).with(/start \"\" \/wait \"#{package_name}\" \/s \/sms  & exit %%%%ERRORLEVEL%%%%/, kind_of(Hash))
      provider.install_package
    end
  end

  context "installs inno installer" do
    let(:provider) { Chef::Provider::Package::Windows::Exe.new(new_resource, :inno) }

    it "calls installer with the correct flags" do
      expect(provider).to receive(:shell_out!).with(/start \"\" \/wait \"#{package_name}\" \/verysilent \/norestart  & exit %%%%ERRORLEVEL%%%%/, kind_of(Hash))
      provider.install_package
    end
  end

  context "installs wise installer" do
    let(:provider) { Chef::Provider::Package::Windows::Exe.new(new_resource, :wise) }

    it "calls installer with the correct flags" do
      expect(provider).to receive(:shell_out!).with(/start \"\" \/wait \"#{package_name}\" \/s  & exit %%%%ERRORLEVEL%%%%/, kind_of(Hash))
      provider.install_package
    end
  end
end
