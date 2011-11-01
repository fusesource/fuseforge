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

require 'net/http'
require 'uri'
require 'benchmark_http_requests'

class User < ActiveRecord::Base
  acts_as_tagger

  has_friendly_id :login

  has_one :prospective_project_member
  belongs_to :phpbb_user, :class_name => "PhpbbUser", :foreign_key => "phpbb_user_id"
  
  serialize :groups_cache

  # Disable mass assignment of the following attributes since they cannot be modified via a user form
  # these values come from Crowd.
  attr_protected :first_name
  attr_protected :last_name
  attr_protected :email
  attr_protected :groups_cache
  attr_protected :cached_at
      
  # Refresh every 5 min
  CROWD_CACHE_TIMEOUT = 60*5;

  # Virtual attributes for data stored in the external datastore
  # attr_accessor :password, :first_name, :last_name, :email, :company, :title, :phone, :country
  
  def self.authenticate_with_crowd_token(crowd_token, request)
    return false if crowd_token.nil?

    # Changed the call to use HTTP_X_FORWARDED_FOR because we are behind a proxy server.  
    unless RAILS_ENV == 'development'  
      return false unless Crowd.new.valid_user_token?(crowd_token, request.user_agent, 
       request.env['HTTP_X_FORWARDED_FOR'].split(',').first)      
    end

    begin
      crowd_user = Crowd.new.find_by_token(crowd_token) # throws SOAP::FaultError
    rescue SOAP::FaultError
      logger.warn "Crowd Error: #{$!}"
      return false
    end

    return false unless CrowdGroup.registered_user_group.user_names.include?(crowd_user.name)

    rc = self.find_or_create_by_login(crowd_user.name)
    rc.crowd_token = crowd_token
    rc.data_refresh(crowd_user)
    rc.save
    return rc
  end
  
  # dummy method for restful_authentication plugin
  def self.authenticate(username, password)
    return nil
  end
  
  def self.find_or_create_by_crowd_login(crowd_login)
    begin
      crowd_user = Crowd.new.find_by_name(crowd_login) # throws SOAP::FaultError
    rescue SOAP::FaultError
      logger.warn "Crowd Error: #{$!}"
      return false
    end

    return false unless CrowdGroup.registered_user_group.user_names.include?(crowd_user.name)

    rc = self.find_or_create_by_login(crowd_user.name)
    rc.data_refresh(crowd_user)
    rc.save
    return rc
  end  
  
  def to_time( dest )
    Time.utc(dest.year, dest.month, dest.day, dest.hour, dest.min, dest.sec)
  end

  def after_find
    if !self.cached_at
      crowd_refresh 
    else 
      now = Time.now.utc.to_i;
      was = to_time(self.cached_at).to_i;
      if ( was+CROWD_CACHE_TIMEOUT < now ) 
        crowd_refresh 
      end
    end
  end
  
  def after_save
    GitRepo.export_ssh_keys if ssh_public_key_changed? 
  end
  
  def self.each_ssh_public_key(&block)
    User.all(:conditions => [ "ssh_public_key is not NULL" ], :order=>'login').each do |user|
      if user.ssh_public_key
        # User may have entered multiple keys (they are seperated by newlines...)
        # Split the keys up and strip them
        keys = user.ssh_public_key.split(/\n|\r/).reject{|x| x.empty?}.map{|x| x.strip} 
        # Get rid of lines that don't look like an ssh key
        keys.reject!{|x| !(x =~ /^(ssh-rsa |ssh-dss )/) }
        keys.each do |key|
          block.call(user, key)
        end
      end
    end  
  end
    
  def crowd_refresh
    begin
      crowd_user = Crowd.new.find_by_name(login) # throws SOAP::FaultError
      return unless CrowdGroup.registered_user_group.user_names.include?(crowd_user.name)
      data_refresh(crowd_user)
      save
    rescue SOAP::FaultError
      logger.warn "Crowd Error: #{$!}"
    end
  end
  
  def cache_invalidate
    self.cached_at = nil
  end

  def data_refresh(crowd_user)   
    @crowd_user = crowd_user
    self.first_name = @crowd_user.first_name
    self.last_name = @crowd_user.last_name
    self.email = @crowd_user.email
    self.groups_cache = Crowd.new.find_group_memberships(@crowd_user.name)
    self.cached_at = Time.now.utc;
  end
  
  def crowd_group_names
    unless self.groups_cache
      self.groups_cache = Crowd.new.find_group_memberships(self.login)
    end
    self.groups_cache
  end
  
  def self.is_registered_user?(crowd_login)
    CrowdGroup.registered_user_group.user_names.include?(crowd_login)
  end
      
  def is_registered_user?
    crowd_group_names.index(CrowdGroup.registered_user_group.name)!=nil 
  end
  
  def is_company_employee?
    crowd_group_names.index(CrowdGroup.company_employee_group.name)!=nil 
  end
  
  def is_jira_fuseforge_developer?
    crowd_group_names.index(CrowdGroup.jira_developer_group.name)!=nil 
  end  
    
  def is_confluence_fuseforge_user?
    crowd_group_names.index(CrowdGroup.confluence_user_group.name)!=nil 
  end  

  def is_icla_on_file?
    crowd_group_names.index(CrowdGroup.forge_icla_group.name)!=nil 
  end  
    
  def is_project_administrator?
    self.is_site_admin? || (not ProjectAdminGroup.group_names.to_set.intersection(crowd_group_names).empty?)
  end
  
  def is_project_administrator_for?(project)
    self.is_site_admin? || (not project.admin_groups.group_names.to_set.intersection(crowd_group_names).empty?)
  end  

  def is_project_member?
    self.is_site_admin? || (not ProjectMemberGroup.group_names.to_set.intersection(crowd_group_names).empty?)
  end
  
  def is_project_member_for?(project)
    self.is_site_admin? || (not project.member_groups.group_names.to_set.intersection(crowd_group_names).empty?)
  end  

  def is_site_admin?
    crowd_group_names.index(CrowdGroup.forge_admin_group.name)!=nil 
  end
  
  def projects
    proj_arr = []
    crowd_group_names.each do |group_name|
      if group_name =~ /forge-(.*)-[admins|members]/
        if proj = Project.find_by_shortname($1)
          proj_arr << proj unless proj_arr.include?(proj)
        end
      end
    end    
    proj_arr
  end
  
  def full_name
    "#{self.first_name} #{self.last_name}"
  end  
    
end