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
class ProjectNewsItemsController < ApplicationController
  skip_before_filter :login_required, :only => [:index, :show]
  
  before_filter :get_project
  before_filter :get_project_news_item, :only => [:show, :edit, :update, :destroy]

  deny :index, :show, :exec => :project_private_and_user_not_member?

  allow :new, :create, :edit, :update, :destroy, :user => :is_project_administrator_for?, :object => :project

  def index
    @project_news_items = @project.news_items

    respond_to do |format|
      format.html { render :action => (params[:from_project_admin] ? 'admin_index' : 'index') }
      format.xml  { render :xml => @project_news_items }
    end
  end

  def show
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @project_news_item }
    end
  end

  def new
    @project_news_item = ProjectNewsItem.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @project_news_item }
    end
  end

  def create
    @project_news_item = ProjectNewsItem.new(params[:project_news_item])
    @project_news_item.project = @project

    respond_to do |format|
      if @project_news_item.save
        flash[:notice] = 'Project News Item was successfully created.'
        format.html { redirect_to(project_project_news_item_path(:project_id => @project.id, :id => @project_news_item.id)) }
        format.xml  { render :xml => @project_news_item, :status => :created, :location => @project_news_item }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @project_news_item.errors, :status => :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @project_news_item.update_attributes(params[:project_news_item])
        flash[:notice] = 'Project News Item was successfully updated.'
        format.html { redirect_to(project_project_news_item_path(:project_id => @project.id, :id => @project_news_item.id)) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @project_news_item.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    @project_news_item.destroy

    respond_to do |format|
      format.html { redirect_to(project_project_news_items_path(:project_id => @project.id)) }
      format.xml  { head :ok }
    end
  end

  private
  
  def get_project
    @project = Project.find(params[:project_id])
  end
  
  def get_project_news_item
    @project_news_item = @project.news_items.find(params[:id])
  end    

  def project_private_and_user_not_member?
    @project.is_private? and not current_user.is_project_member_for?(@project)
  end  
end
