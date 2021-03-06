# ===========================================================================
# Copyright (C) 2009, Progress Software Corporation and/or its 
# subsidiaries or affiliates.  All rights reserved.
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
# ===========================================================================

require 'command_executor'

class Repository < ActiveRecord::Base
  belongs_to :project
  
  SVN_ROOT = '/var/forge/svn'

  def repos_filepath
    "#{SVN_ROOT}/repos"
  end

  def repo_filepath
    "#{repos_filepath}/#{key}"
  end

  def httpd_conf_filepath
    "#{SVN_ROOT}/httpd.conf/#{key}"
  end
  
  def authz_filepath
    "#{SVN_ROOT}/authz/#{key}"
  end


  def before_save
    self.external_url = '' if use_internal?
    project.deploy if use_internal_changed?
  end
  
  def before_destroy
    # return true unless exists_internally?

    # Disable the apache site file, reload the apache config, delete the apache site file, delete the repo permissions file,
    # and delete the repository.
    # conn = open_conn
    # disable_apache_site_file(apache_site_file_name, conn)     
    # reload_apache_config(conn)
    # remove_apache_site_file(apache_site_file_name, conn)
    # remove_file(authz_filepath, conn)
    # remove_directory(repo_filepath, conn)
    # close_conn(conn)
    true
  end
  
  def is_active?
    use_internal? or not external_url.blank?
  end
  
  def internal_url
    "#{FORGE_URL}/svn/#{key}"
  end  
  
  def url
    use_internal? ? internal_url : external_url
  end

  def commits
    total_commits = 0
    begin
      IO.popen("svnlook youngest #{repo_filepath}") { |x| total_commits = x.gets.chomp.to_i } if exists_internally?
    rescue
    end
    total_commits
  end
  
  def last_commit_at
    last_commit_at_time = ''
    begin
      IO.popen("svnlook date #{repo_filepath}") { |x| last_commit_at_time = x.gets.gsub(/\+.*/, '') + ' UTC' } if exists_internally?
    rescue
    end
    last_commit_at_time
  end
  
  def create_internal(reload=true)
    return true unless use_internal?

    apache_user = SVN_CONFIG[:user]
    
    # if SVN_CONFIG[:ssh] is nil, then commands are run locally 
    CommandExecutor.open(SVN_CONFIG[:ssh]) do |x|
    
      # Only create the repo if it does not exist
      if !x.dir_exists?(repo_filepath, apache_user)
        x.system("svnadmin create #{repo_filepath}", apache_user)==0 or raise 'Error creating repository!'
      end
      
      #
      # Setup a post-commit hook to email the mailing list if the project has
      # a commits mailing list configured.
      ml = project.mailing_lists.find_by_name("commits")
      if ml
        x.write(post_commit_hook_content(ml), "#{repo_filepath}/hooks/post-commit", apache_user) 
        x.system("chmod a+x #{repo_filepath}/hooks/post-commit", apache_user)
      end
    
      # Generate the config files for the repo.
      x.write(authz_file_content, authz_filepath) 
      x.write(httpd_conf_content, httpd_conf_filepath)==0 or raise 'Error creating apache site file!'

      if reload
        x.system('/etc/init.d/apache2 reload', "root")==0 or raise 'Error reloading apache config!'
      end
      
    end
    true
    
  end    
  
  def update_permissions
    return true unless use_internal?
    
    CommandExecutor.open(SVN_CONFIG[:ssh]) do |x|
      x.write(authz_file_content, authz_filepath) 
    end
    true
  rescue => error
    logger.error """Error update the svn permissions: #{error}\n#{error.backtrace.join("\n")}"""
  end
  
  private
  
  def key
    self.project.shortname.downcase
  end

  def crowd_app_name
    CROWD_CONFIG["http_application_name"]
  end
  def crowd_app_password
    CROWD_CONFIG["http_application_password"]
  end
  def crowd_app_expire
    CROWD_CONFIG["http_application_expire"] || 600
  end
  
  def post_commit_hook_content(ml)
    rc = <<EOS
#!/bin/bash
/usr/share/subversion/hook-scripts/commit-email.pl "$1" "$2" --from #{ml.post_address} -s "svn commit:" #{ml.post_address}
EOS
    rc
  end

  def authz_file_content
    rc = <<EOF
[/]
* =
@#{CrowdGroup.forge_admin_group.name} = rw
EOF
    self.project.admin_groups.each do |group|
      rc += "@#{group.name} = rw\n"
    end
    self.project.member_groups.each do |group|
      rc += "@#{group.name} = rw\n"
    end
    if self.project.is_private? 
      self.project.readonly_groups.each do |group|
        rc += "@#{group.name} = r\n"
      end
    else
      rc += "@registered-users = r\n" 
    end
    return rc;
  end

  def httpd_conf_content
    rc = <<EOF
<Location /forge/svn/#{key}>

  DAV svn
  SVNPath #{repo_filepath}
  SVNPathAuthz off

  AuthType Basic
  AuthName "FUSE Forge Repository"

  PerlAuthenHandler Apache::CrowdAuth
  PerlSetVar CrowdAppName #{crowd_app_name}
  PerlSetVar CrowdAppPassword #{crowd_app_password}
  PerlSetVar CrowdSOAPURL #{CROWD_URL}/services/SecurityServer

  PerlAuthzHandler Apache::CrowdAuthz
  PerlSetVar CrowdAuthzSVNAccessFile #{authz_filepath}

  PerlSetVar CrowdCacheEnabled on
  PerlSetVar CrowdCacheLocation #{SVN_ROOT}/crowd-cache
  PerlSetVar CrowdCacheExpiry #{crowd_app_expire}

  require valid-user

</Location>
EOF
    return rc;
  end

end