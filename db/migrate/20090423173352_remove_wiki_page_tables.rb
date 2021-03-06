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
class RemoveWikiPageTables < ActiveRecord::Migration
  def self.up
    drop_table :wiki_page_attachment_downloads
    drop_table :wiki_page_attachments
    drop_table :wiki_page_versions
    drop_table :wiki_pages
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration, "Can't recover the deleted wiki tables"
  end
end
