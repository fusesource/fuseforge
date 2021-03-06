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
class CreateWikiPageAttachments < ActiveRecord::Migration
  def self.up
    create_table :wiki_page_attachments do |t|
      t.integer  :wiki_page_id
      t.string   :attached_file_file_name
      t.string   :attached_file_content_type
      t.integer  :attached_file_file_size
      t.datetime :attached_file_updated_at
      t.integer  :created_by_id
      t.integer  :updated_by_id

      t.timestamps
    end
  end

  def self.down
    drop_table :wiki_page_attachments
  end
end
