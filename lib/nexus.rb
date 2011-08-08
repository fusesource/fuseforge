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
require 'rest_client'
require 'json'

# Provides a simple interface to Nexus restful services.
# 
# @author <a href="http://hiramchirino.com">Hiram Chirino</a>
class Nexus
    
  def self.open(config, &block)
    rc = Nexus.new(config)
    if( block ) 
      begin
        return block.call(rc)
      ensure
        rc.close
      end
    else
      return rc
    end
  end

  def initialize(config)
    @url = config
  end
  
  def close
  end 

private
    
  def url_base
    "#{@url}/service/local"
  end
  
  def dc    
    "_dc=#{Time.now.to_i}"
  end 

  def get(url, headers={}, &block)
    headers = {:content_type => :json, :accept => :json}.merge(headers)
    from_json(RestClient.get(url, headers, &block))
  end
  def delete(url, headers={}, &block)
    headers = {:content_type => :json, :accept => :json}.merge(headers)
    from_json(RestClient.delete(url, headers, &block))
  end
  def post(url, data, headers={}, &block)
    headers = {:content_type => :json, :accept => :json}.merge(headers)
    from_json(RestClient.post(url, to_json(data), headers, &block))
  end
  def put(url, data, headers={}, &block)
    headers = {:content_type => :json, :accept => :json}.merge(headers)
    from_json(RestClient.put(url, to_json(data), headers, &block))
  end
  
  def from_json(value)
    if value == nil || value.empty?
      nil
    else
      JSON.parse value
    end
  end
  
  def to_json(value)
    if value == nil
      ""
    else
      value.to_json
    end
  end
  
public

  def status    
    get "#{url_base}/status?#{dc}"
  end 

  def login
    get "#{url_base}/authentication/login?#{dc}"
  end 
  
  # ===================================================================
  # repositories access
  # ===================================================================
  def get_repositories
    get("#{url_base}/repositories?#{dc}")["data"]
  end 
  def get_repositories_by_name
    Hash[ *get_repositories.collect {|x| [x["name"], x["id"]] }.flatten ]
  end 

  # ===================================================================
  # repo_targets access
  # ===================================================================
  def post_repo_target(repo_target)
    repo_target= {
      "name"=>nil, 
      "contentClass"=>"maven2", 
      "patterns"=>[]
    }.merge(repo_target)
    request = {"data"=>repo_target}
    post("#{url_base}/repo_targets", request)["data"]
  end 
  def get_repo_targets
    get("#{url_base}/repo_targets?#{dc}")["data"]
  end 
  def get_repo_targets_by_name
    Hash[ *get_repo_targets.collect {|x| [x["name"], x["id"]] }.flatten ]
  end 
  def delete_repo_target(id)
    delete "#{url_base}/repo_targets/#{id}"
  end 

  # ===================================================================
  # privileges access
  # ===================================================================
  def post_privileges_target(privileges_targe)
    privileges_target = {
      "name"=>nil, 
      "repositoryTargetId"=>nil,
      "description"=>"", 
      "repositoryId"=>"",
      "repositoryGroupId"=>"",
      "method"=>["create","read","update","delete"],
      "type"=>"target"
    }.merge(privileges_targe);
    request = {"data"=>privileges_target}
    post("#{url_base}/privileges_target", request)["data"]
  end 
  def get_privileges
    get("#{url_base}/privileges?#{dc}")["data"]
  end 
  def get_privileges_by_name
    Hash[ *get_privileges.collect {|x| [x["name"], x["id"]] }.flatten ]
  end 
  def delete_privilege(id)
    puts "deleting priv: #{id}"
    delete "#{url_base}/privileges/#{id}"
  end 

  # ===================================================================
  # staging_profile access
  # ===================================================================
  def post_staging_profile(staging_profile)
    staging_profile = { 
      "name"=>nil,
      "repositoryTemplateId"=>"default_hosted_release",
      "repositoryType"=>"maven2",
      "targetGroups"=>["public"],
      "finishNotifyRoles"=>[],
      "promotionNotifyRoles"=>[],
      "promoteRuleSets"=>[],
      "inProgress"=> false,
      "order"=> 99,
      "stagingRepositoryIds"=> [],
      "stagedRepositoryIds"=> [],
      "dropNotifyRoles"=> [],
      "mode"=> "DEPLOY",
      "finishNotifyCreator"=> false,
      "promotionNotifyCreator"=> false,
      "dropNotifyCreator"=> false
    }.merge(staging_profile);
    request = {"data"=>staging_profile}
    post("#{url_base}/staging/profiles?#{dc}", request)["data"]
  end 
  def get_staging_profile
    get("#{url_base}/staging/profiles?#{dc}")["data"]
  end 
  def get_staging_profile_by_name
    Hash[ *get_staging_profile.collect {|x| [x["name"], x["id"]] }.flatten ]
  end 
  def delete_staging_profile(id)
    delete "#{url_base}/staging/profiles/#{id}"
  end 
  
  # ===================================================================
  # staging_rule_set access
  # ===================================================================
  def get_staging_rule_sets
    get("#{url_base}/staging/rule_sets?#{dc}")["data"]
  end 
  def get_staging_rule_sets_by_name
    Hash[ *get_staging_rule_sets.collect {|x| [x["name"], x["id"]] }.flatten ]
  end 

  # ===================================================================
  # role access
  # ===================================================================
  def post_role(role)
    role = {
      "id"=>nil,
      "name"=>nil, 
      "description"=>"", 
      "sessionTimeout"=>"60",
      "roles"=>[],
      "privileges"=>[]
    }.merge(role);
    post("#{url_base}/roles", {"data"=>role})["data"]
  end 
  def put_role(role)
    id = role["id"]
    put("#{url_base}/roles/#{id}", {"data"=>role})["data"]
  end 
  def get_roles
    get("#{url_base}/roles?#{dc}")["data"]
  end 
  def get_roles_by_name
    Hash[ *get_roles.collect {|x| [x["name"], x["id"]] }.flatten ]
  end 
  def delete_role(id)
    puts "deleting priv: #{id}"
    delete "#{url_base}/roles/#{id}"
  end 
    
  # ===================================================================
  # external_role access
  # ===================================================================
  def get_external_roles
    get("#{url_base}/external_role_map/all?#{dc}")["data"]
  end 
  def get_external_roles_by_name
    Hash[ *get_privileges.collect {|x| [x["name"], x["id"]] }.flatten ]
  end 
end
